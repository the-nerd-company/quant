# Testing Guide

This project includes two types of tests:

## 🟢 Unit Tests (Default - Fast & Reliable)

These tests use **mocked HTTP responses** and run by default:

```bash
# Run all tests (mocked only, no real API calls)
mix test

# Run only mocked tests explicitly  
mix test --only mocked
```

**Features:**
- ✅ **Fast** - No network latency
- ✅ **Reliable** - No external dependencies
- ✅ **No rate limits** - Controlled mock responses
- ✅ **Offline** - Works without internet connection
- ✅ **CI/CD friendly** - Predictable and stable

## 🟠 Integration Tests (Optional - Real API Calls)

These tests make **real HTTP requests** to external APIs and are disabled by default:

```bash
# Run integration tests (requires API keys and internet)
mix test --include integration

# Run both mocked and integration tests
mix test --include integration --include mocked

# Run only integration tests
mix test --only integration
```

**Requirements:**
- 🌐 **Internet connection**
- 🔑 **Valid API keys** (Alpha Vantage, etc.)
- ⏱️ **Respect rate limits**
- 💰 **May consume API quota**

## 📋 Test Categories

| Test Type | Tag | Default | Purpose |
|-----------|-----|---------|---------|
| Mocked Tests | `@moduletag :mocked` | ✅ Enabled | Fast unit testing with controlled responses |
| Integration Tests | `@moduletag :integration` | ❌ Disabled | Real API validation and end-to-end testing |

## 🔧 Configuration

### API Keys for Integration Tests

Set these environment variables for integration tests:

```bash
export ALPHA_VANTAGE_API_KEY="your_alpha_vantage_key"
export TWELVE_DATA_API_KEY="your_twelve_data_key"
```

### Test Environment Setup

The test environment automatically:
- Uses **mock HTTP client** for unit tests
- Switches to **real HTTP client** for integration tests  
- Configures higher rate limits for testing
- Disables telemetry and logging noise

## 🎯 Best Practices

### For Development
- Run `mix test` frequently - fast mocked tests catch issues quickly
- Use integration tests sparingly - they're slower and consume API quota
- Add new functionality to mocked tests first

### For CI/CD
- Default `mix test` runs only mocked tests (fast, reliable)
- Optional integration test stage with `mix test --include integration`
- Separate API key management for production vs testing

### For Debugging
- Use mocked tests to isolate logic issues
- Use integration tests to verify real API behavior
- Mix both when investigating API changes or data format issues

## 📁 Test Structure

```
test/
├── support/                          # Test utilities
│   ├── http_mock.ex                 # Mock HTTP responses
│   ├── http_client_mock.ex          # Mock HTTP client
│   └── test_helper.exs              # Test configuration
├── providers/
│   ├── all_providers_mocked_test.exs # 🟢 Mocked provider tests
│   ├── yahoo_finance_test.exs        # 🟠 Real Yahoo Finance tests  
│   ├── alpha_vantage_test.exs        # 🟠 Real Alpha Vantage tests
│   └── binance_test.exs              # 🟠 Real Binance tests
├── fin_explorer_test.exs             # 🟠 Main API integration tests
└── test_helper.exs                   # Global test configuration
```

## 🚀 Examples

### Quick Development Cycle
```bash
# Fast feedback loop during development
mix test                              # ~0.3s - All mocked tests
mix test test/providers/all_providers_mocked_test.exs  # ~0.2s - Specific tests
```

### API Validation
```bash
# Validate real API behavior (slower)
mix test --include integration test/providers/yahoo_finance_test.exs  # Real Yahoo Finance
mix test --include integration        # All real APIs
```

### Complete Testing
```bash
# Run everything (development/CI)
mix test --include integration --include mocked
```

This approach gives you the **best of both worlds**:
- Fast, reliable unit tests for everyday development  
- Real API validation when you need it
- Clear separation of concerns
- No external dependencies by default