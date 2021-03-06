.PHONY: all test

TESTS           := $(basename $(wildcard tests/test_*.v))
TESTRESULTS     := $(addsuffix .lxt2, ${TESTS})


MODULE_V    := postcode.v


all:
	@echo "Run 'make test' to run the test suite."

test: ${TESTRESULTS}
	@#echo "TODO: Aggregate test results, pass/fail"

testclean:
	rm -f ${TESTRESULTS} ${TESTRESULTS_VCD}

# Run a test to produce the test results
tests/%.lxt2:	tests/%
	@echo "Running test $<"
	@vvp $< -lxt2
	@echo

# Build the test using Icarus Verilog
tests/%:	tests/%.v ${MODULE_V} top.v FORCE
	@iverilog -I./tests -o $@ $< ${MODULE_V} post_box_usb.v

test_post_box_usb: tests/test_post_box_usb.lxt2

.PHONY: FORCE

FORCE:
