# Integration Tests

This directory contains integration tests that make real HTTP requests to financial data APIs.

## Structure

```
test/integration/
├── README.md                                   # This file
├── integration_test.exs                        # Core integration tests  
├── fin_explorer_test.exs                      # Main API integration tests
├── test_runner.ex                             # Test runner helpers
└── providers/                                 # Provider-specific integration tests
    ├── yahoo_finance_integration_test.exs     # Yahoo Finance API tests
    ├── alpha_vantage_integration_test.exs     # Alpha Vantage API tests
    └── twelve_data_integration_test.exs       # Twelve Data API tests
```

## Running Integration Tests

### Prerequisites

Set the required environment variables:

```bash
export ALPHA_VANTAGE_API_KEY=your_key_here
export TWELVE_DATA_API_KEY=your_key_here
export YAHOO_FINANCE_INTEGRATION_TEST=1  # Optional, for Yahoo Finance tests
```

### Run All Integration Tests

```bash
mix test test/integration --include integration
```

### Run Specific Provider Tests

```bash
# Yahoo Finance (no API key required)
mix test test/integration/providers/yahoo_finance_integration_test.exs --include integration

# Alpha Vantage (requires API key)
mix test test/integration/providers/alpha_vantage_integration_test.exs --include integration

# Twelve Data (requires API key)
mix test test/integration/providers/twelve_data_integration_test.exs --include integration
```

### Run Core Integration Tests

```bash
mix test test/integration/integration_test.exs --include integration
```

## Test Behavior

- **Without API keys**: Tests will gracefully handle missing API keys and test error scenarios
- **With API keys**: Tests will make actual API calls and validate real responses
- **Rate limiting**: Tests respect provider rate limits and may take longer to run
- **Network dependent**: Tests require internet connectivity

## Environment Check

You can check your environment setup by running:

```bash
cd test/integration && elixir test_runner.ex
```

## Notes

- Integration tests are excluded by default to keep regular test runs fast
- These tests make real HTTP requests and are subject to API rate limits
- Test execution time varies based on API response times and rate limits
- Some providers offer "demo" API keys for testing purposes