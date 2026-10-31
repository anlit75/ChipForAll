"""
A self-checking random test: reference model, monitor, scoreboard.

test_blinky_cocotb.py asserts on moments somebody chose by hand. This file
does the other half of verification: a model that says what the design
*should* do, a loop that samples what it did, and a comparison on every
cycle, under reset pulses nobody wrote out.

Repeating a failure. cocotb seeds Python's random module itself and logs
the seed it used ("Seeding Python random module with 1789965785"), so a
run that failed can be run again exactly:

    make cocotb SEED=1789965785

On the gates, `make gatesim SEED=1789965785` replays it the same way.

Like the other file, this one touches only clk, rst and led, so it runs on
the RTL and on the netlist. Every cycle is a trip through Python, so the run
is bounded: one rise of led, a second one after a reset, then a few random reset pulses.

What this does not check: that reset acts without a clock edge. rst changes
here at a falling edge and led is read at the next one, so a synchronous
reset passes. The directed test reset_in_the_middle_restarts_the_count
checks it. Recovery and removal are a static-timing question, and the
nine-line summary does not carry them: its two slack rows are setup and
hold, which are different checks. The per-corner reports do. This design's
run puts `recovery check against rising-edge clock clk` under
`Path Group: asynchronous` in all nine of them, which CI prints.
"""

import random

import cocotb
from cocotb.triggers import Edge, FallingEdge, First, Timer
from cocotb.utils import get_sim_time

# Must match WIDTH in rtl/blinky.v. A netlist has no parameter to read.
WIDTH = 16
LIMIT = 1 << WIDTH
HALF = 1 << (WIDTH - 1)   # the count at which led rises

RESETS = 3                # random reset pulses after the two fixed ones
SPREAD = HALF // 4        # longest free run before a random pulse


async def fast_clock(sig, period_ns=10):
    """
    The same square wave as cocotb's Clock, with half the simulator callbacks:
    a write with setimmediatevalue needs no extra read-write phase.
    """
    half = Timer(period_ns // 2, units="ns")
    while True:
        sig.setimmediatevalue(1)
        await half
        sig.setimmediatevalue(0)
        await half


class BlinkyModel:
    """
    What blinky should do, in Python: count, wrap, clear on reset.

    Deliberately not a transcription of the RTL. The same behaviour
    written a second way is the only thing a scoreboard can usefully
    disagree with the design about.
    """

    def __init__(self):
        self.count = 0

    def clock(self, rst):
        self.count = 0 if rst else (self.count + 1) % LIMIT

    def reset(self):
        self.count = 0

    @property
    def led(self):
        return (self.count >> (WIDTH - 1)) & 1


def plan():
    """
    Cycles to run free before each reset pulse, as (gap, pulse length).

    The first gap is longer than the rise at HALF, so a run cannot come back
    green having watched a signal that never moved. The second lands next to
    that rise again, counted from the reset, where an off-by-one would show.
    The rest are short or medium, to keep the run short.
    """
    steps = [(HALF + 10, 2), (HALF + random.randint(-3, 3), random.randint(1, 3))]
    for _ in range(RESETS):
        gap = random.randint(1, 50) if random.random() < 0.5 else random.randint(1, SPREAD)
        steps.append((gap, random.randint(1, 3)))
    return steps


@cocotb.test()
async def random_resets_match_the_model(dut):
    """Random reset pulses over several periods; led checked every cycle."""
    cocotb.start_soon(fast_clock(dut.clk))
    model = BlinkyModel()
    rst = 1
    dut.rst.value = 1

    steps = plan()
    # Reset is held for a few edges first, then each step runs free for its
    # gap and pulses rst for its length.
    schedule = [1] * 3
    for gap, length in steps:
        schedule += [0] * gap + [1] * length

    transitions = resets = 0
    previous = 0
    since = 0      # cycles since rst last changed
    cycle = 0
    while cycle < len(schedule):
        # A stretch where rst stays put and the model's led cannot change is
        # waited out with one Timer. led is watched for an Edge meanwhile: one
        # that comes early is compared at the falling edge that sees it, so a
        # wrong led is reported at the same cycle as when every cycle is read.
        # The last two cycles before any change are still read one by one.
        if cycle and since >= 3:
            run = 0
            while cycle + run < len(schedule) and schedule[cycle + run] == rst:
                run += 1
            if rst:
                still = run
            else:
                still = (LIMIT if model.led else HALF) - model.count - 1
            skip = min(run, still) - 2
            if skip > 0:
                # The wait ends 2 ns after a falling edge, never on one, so the
                # FallingEdge below is the next one and not this one again.
                start = get_sim_time("ps")
                timer = Timer(skip * 10 + 2, units="ns")
                early = await First(Edge(dut.led), timer) is not timer
                if early:
                    # Stop at the falling edge before the one that sees it,
                    # and read the cycles from there as usual.
                    skip = int(get_sim_time("ps") - start) // 10000
                for _ in range(skip):
                    model.clock(rst)
                cycle += skip
                since = 0 if early else since + skip
                if skip > 0:
                    continue

        want = schedule[cycle]
        await FallingEdge(dut.clk)
        model.clock(rst)
        if int(dut.led.value) != model.led:
            raise AssertionError(
                f"led is {int(dut.led.value)}, model says {model.led}: "
                f"cycle {cycle}, rst was {rst}, model count {model.count}"
            )
        if model.led != previous:
            transitions += 1
            previous = model.led

        # Drive rst for the edge ahead. A reset clears the count at once.
        if want and not rst:
            resets += 1
        since = since + 1 if want == rst else 0
        rst = want
        dut.rst.value = rst
        if rst:
            model.reset()
        cycle += 1

    assert transitions >= 1, (
        f"led moved {transitions} times in {len(schedule)} cycles. The "
        "stimulus never reached an edge, so this run checked nothing."
    )

    dut._log.info(
        f"{len(schedule)} cycles checked, {resets} resets, "
        f"{transitions} led transitions"
    )
