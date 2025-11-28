.PHONY: test clean help

help:
	@echo "cyclops.vim - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  test    - Run all unit tests"
	@echo "  clean   - Remove temporary files"
	@echo "  help    - Show this help message"

test:
	@echo "Running cyclops.vim tests..."
	@vim -Nu test/run_tests.vim

clean:
	@echo "Cleaning up..."
	@find . -name '*.swp' -delete
	@find . -name '*.swo' -delete
	@find . -name '*~' -delete
