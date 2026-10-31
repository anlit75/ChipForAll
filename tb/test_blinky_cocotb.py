"""
cocotb tests for blinky: Python coroutines driving the design.

These tests touch only the ports clk, rst and led. That is what lets the same
file run on the RTL (`make sim`) and on the gates (`make gatesim`): a netlist
keeps the ports, and the register and the parameter inside are gone.

Without access to the counter, the only way to see led move is to wait for it.
That is why rtl/blinky.v has a small WIDTH: led rises after 2**(WIDTH-1) clock
cycles, and each of those cycles costs simulator time.
"""

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer

# Must match WIDTH in rtl/blinky.v. A netlist has no parameter to read, so the
# tests cannot ask the design, and one constant per file is the simplest copy.
WIDTH = 16
HALF = 1 << (WIDTH - 1)  # cycles led stays at each level
PERIOD = 1 << WIDTH      # cycles of one full blink

# How long to wait after an edge before reading led. On the gates a flip-flop
# takes a moment to change its output, and RisingEdge resumes before that.
SETTLE_NS = 3


async def fast_clock(sig):
    """
    The same 10 ns square wave as cocotb's Clock, with half the simulator
    callbacks: a write with setimmediatevalue needs no read-write phase.
    """
    half = Timer(5, units="ns")
    while True:
        sig.setimmediatevalue(1)
        await half
        sig.setimmediatevalue(0)
        await half


async def settle():
    await Timer(SETTLE_NS, units="ns")


async def start(dut):
    """Clock running, reset applied for two edges, then released."""
    cocotb.start_soon(fast_clock(dut.clk))
    dut.rst.value = 1
    await ClockCycles(dut.clk, 2)
    await settle()
    dut.rst.value = 0


async def led_after(dut, edges):
    """Wait until `edges` rising edges have passed, then return led."""
    # The first edge is awaited, the others are one Timer of 10 ns each: the
    # same moment as ClockCycles, without a wake-up of Python on every edge.
    await RisingEdge(dut.clk)
    if edges > 1:
        await Timer((edges - 1) * 10, units="ns")
    await settle()
    return int(dut.led.value)


@cocotb.test()
async def reset_holds_led_low(dut):
    cocotb.start_soon(fast_clock(dut.clk))
    dut.rst.value = 1
    await ClockCycles(dut.clk, 2)
    for cycle in range(10):
        await settle()
        assert dut.led.value == 0, f"led was {dut.led.value} in cycle {cycle} of reset, expected 0"
        await RisingEdge(dut.clk)


@cocotb.test()
async def led_rises_half_a_period_after_reset(dut):
    await start(dut)
    # The first edge after release is edge 1. led must be low after edge
    # HALF-1 and high after edge HALF, not a cycle either side.
    led = await led_after(dut, HALF - 1)
    assert led == 0, f"led was {led} after {HALF - 1} cycles, expected 0: it should rise at cycle {HALF}"
    led = await led_after(dut, 1)
    assert led == 1, f"led was {led} after {HALF} cycles, expected 1: it should rise at cycle {HALF}"


@cocotb.test()
async def led_toggles_with_a_full_period(dut):
    await start(dut)
    led = await led_after(dut, HALF - 1)
    assert led == 0, f"led was {led} after {HALF - 1} cycles, expected 0: it should rise at cycle {HALF}"
    led = await led_after(dut, 1)
    assert led == 1, f"led was {led} after {HALF} cycles, expected 1: it should rise at cycle {HALF}"
    led = await led_after(dut, HALF - 1)
    assert led == 1, f"led was {led} after {PERIOD - 1} cycles, expected 1: it should fall at cycle {PERIOD}"
    led = await led_after(dut, 1)
    assert led == 0, f"led was {led} after {PERIOD} cycles, expected 0: it should fall at cycle {PERIOD}"


@cocotb.test()
async def reset_in_the_middle_restarts_the_count(dut):
    await start(dut)
    led = await led_after(dut, HALF + 5)
    assert led == 1, f"led was {led} after {HALF + 5} cycles, expected 1: it should be high before the reset"

    # Reset is asynchronous: led must fall without waiting for a clock edge.
    # The edge is 10 ns away, the check comes well before it.
    dut.rst.value = 1
    await settle()
    assert dut.led.value == 0, f"led was {dut.led.value} right after rst went high, expected 0: reset should not wait for a clock edge"

    await ClockCycles(dut.clk, 2)
    await settle()
    assert dut.led.value == 0, f"led was {dut.led.value} after 2 clock edges with rst held, expected 0"
    dut.rst.value = 0

    # The count starts again from zero, so the rise is HALF cycles away.
    led = await led_after(dut, HALF - 1)
    assert led == 0, f"led was {led} after {HALF - 1} cycles from reset, expected 0: it should rise at cycle {HALF}"
    led = await led_after(dut, 1)
    assert led == 1, f"led was {led} after {HALF} cycles from reset, expected 1: it should rise at cycle {HALF}"
