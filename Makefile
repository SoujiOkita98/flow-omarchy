.PHONY: check

# Tests against a local mock provider (no mic, network or key) and validates
# the Omarchy plugin manifest when Omarchy is available.
check:
	bash -n bin/flow-omarchy
	test/run.sh
	if command -v omarchy-plugin-validate >/dev/null; then omarchy-plugin-validate .; fi
