# Quant.Explorer Cache System - Development Instructions

## Project Overview
Build a high-performance cache layer for Quant.Explorer financial API that handles 100k+ requests/second while minimizing external API calls by 80-90%. The cache must be backend-agnostic and intelligently manage fragmented data across multiple providers.

## Core Architecture Rules

### 1. Cache Strategy: Single Standardized Layer Only
- **Store Quant.Explorer's standardized DataFrames directly** (no raw data layer)
- **Use Parquet format** for serialization (efficient, preserves schema)
- **Primary backend: ETS** (ultra-fast in-memory storage)
- **Support multiple backends** via abstraction layer (Redis, InfluxDB, PostgreSQL as optional)

### 2. Cache Key Format (CRITICAL)
```
"finex:{symbol}:{interval}:{actual_start_ts}:{actual_end_ts}:{provider}:{currency}:{fields}_{version}"
```

**Key Rules**:
- Use **ACTUAL received timestamp ranges**, not requested ranges
- Providers often return bonus data (store the full range received)
- Example: `"finex:AAPL:1d:1704067200:1706918400:yahoo:usd:ohlcv_v1"`

### 3. Fragment Strategy
- **Time-based fragmentation** using actual data boundaries
- **Fragment sizes vary by interval**:
  - Intraday (1m-1h): 1-24 hours per fragment
  - Daily (1d): 30 days per fragment  
  - Weekly/Monthly: 90-365 days per fragment
- **Store metadata** about requested vs actual ranges

## Implementation Requirements

### Phase 1: Foundation (Week 1-2)
- [ ] **Backend Abstraction Layer**
  - Create `CacheBackend` behaviour with: `get/1`, `put/3`, `get_multiple/1`, `scan_prefix/1`, `delete/1`
  - Implement `ETSBackend` as primary backend
  - Implement `RedisBackend` for optional distribution

- [ ] **Cache Key Management**
  - Build cache key generator using actual timestamp ranges
  - Implement fragment overlap detection logic
  - Create fragment registry to track what data exists

- [ ] **Quant.Explorer Integration**
  - Wrap `Quant.Explorer.StandardizedAPI` with caching layer
  - Preserve all Quant.Explorer functionality (same API interface)
  - Handle provider fallbacks seamlessly

### Phase 2: Smart Query Planning (Week 3-4)
- [ ] **Gap Detection Engine**
  - Analyze incoming queries vs cached fragments
  - Identify time gaps (missing time periods)
  - Identify field gaps (missing DataFrame columns)
  - Handle currency mismatches

- [ ] **Query Optimization**
  - Merge adjacent time gaps to minimize API calls
  - Leverage bonus data from previous fetches
  - Smart provider selection based on cache coverage
  - Fragment reassembly for complex queries

- [ ] **Actual Data Range Handling**
  - Store what providers actually returned (not what was requested)
  - Track bonus data before/after requested ranges
  - Handle market hours vs 24/7 data differences
  - Manage weekend/holiday gaps intelligently

### Phase 3: Performance Optimization (Week 5-6)
- [ ] **TTL Management**
  - Dynamic TTL based on data type and volatility
  - Real-time data: 5-60 minutes
  - Daily data: 24 hours
  - Historical data: 7+ days

- [ ] **Memory Management**
  - Fragment coalescing for small fragments
  - Intelligent eviction policies
  - Memory usage monitoring and alerts
  - Fragment compression strategies

- [ ] **Prefetching Logic**
  - Predict likely future queries based on patterns
  - Prefetch during low-usage periods
  - Market hours awareness for different exchanges

### Phase 4: Production Features (Week 7-8)
- [ ] **Monitoring & Observability**
  - Cache hit/miss rates by provider and symbol
  - Fragment utilization statistics
  - API call reduction metrics
  - Response time monitoring

- [ ] **Error Handling**
  - Circuit breaker for failing providers
  - Graceful degradation when cache unavailable
  - Data quality validation
  - Corruption detection and recovery

- [ ] **Configuration Management**
  - Environment-specific fragment sizes
  - Provider timeout settings
  - Cache size limits and policies
  - Feature flags for experimental optimizations

## Critical Business Logic Rules

### Rule 1: Always Store Actual Received Data
```elixir
# WRONG: Store requested range
cache_key = "finex:AAPL:1d:#{requested_start}:#{requested_end}:yahoo:usd:ohlcv_v1"

# CORRECT: Store actual received range
cache_key = "finex:AAPL:1d:#{actual_first_timestamp}:#{actual_last_timestamp}:yahoo:usd:ohlcv_v1"
```

### Rule 2: Leverage Bonus Data Aggressively
- When providers return extra data, store all of it
- Use bonus data to satisfy future queries without API calls
- Track coverage ratios (actual vs requested data ranges)

### Rule 3: Field-Level Intelligence
- Cache fragments can have different field combinations
- Merge fragments with overlapping time ranges but different fields
- Prefer complete field sets over partial ones

### Rule 4: Provider Fallback Strategy
- If primary provider cache miss, check secondary providers
- Quality scoring: provider reliability + data completeness
- Automatic failover during provider outages

### Rule 5: Fragment Boundary Alignment
- Align fragments to natural boundaries (hour/day/month)
- Maximizes cache reuse across different query patterns
- Reduces fragmentation and improves hit rates

## API Design Requirements

### Cache-Aware Quant.Explorer Wrapper
```elixir
# Must maintain exact same API as Quant.Explorer
Quant.Explorer.CachedAPI.history(symbols, opts)
Quant.Explorer.CachedAPI.quote(symbols, opts) 
Quant.Explorer.CachedAPI.search(query, opts)

# Additional cache-specific functions
Quant.Explorer.CachedAPI.cache_stats()
Quant.Explorer.CachedAPI.warm_cache(symbols, intervals, date_ranges)
Quant.Explorer.CachedAPI.invalidate_cache(pattern)
```

### Response Metadata
Add cache metadata to responses:
```elixir
%{
  data: dataframe,
  cache_info: %{
    hit_rate: 0.85,
    cache_keys_used: ["finex:AAPL:1d:..."],
    api_calls_made: 1,
    response_time_ms: 45,
    data_freshness: "5 minutes ago"
  }
}
```

## Performance Targets

### Success Metrics
- **95%+ cache hit rate** for queries within last 24 hours
- **Sub-10ms response time** for cached data
- **90%+ reduction** in external API calls
- **100k+ concurrent requests** support
- **99.9% uptime** for cache layer

### Quality Metrics  
- **Zero data corruption** during cache operations
- **Consistent schemas** across all cached fragments
- **Graceful degradation** when backends fail
- **Sub-second recovery** from backend failures

## Testing Requirements

### Unit Tests
- Cache key generation with various timestamp scenarios
- Fragment overlap detection accuracy
- Query planning logic with complex multi-symbol requests
- Backend abstraction layer compliance

### Integration Tests
- Full Quant.Explorer integration with real provider data
- Multi-backend failover scenarios
- Large-scale fragment management
- Memory usage under load

### Performance Tests  
- 100k+ concurrent request handling
- Cache hit rate optimization
- Fragment reassembly performance
- Memory leak detection

## Configuration Examples

### Development Environment
```elixir
config :quant, :cache,
  backend: Quant.Explorer.Cache.ETSBackend,
  fragment_size: :small,  # Smaller fragments for testing
  ttl_multiplier: 0.1,    # Shorter TTLs for development
  prefetch_enabled: false
```

### Production Environment
```elixir
config :quant, :cache,
  backend: Quant.Explorer.Cache.RedisBackend,
  fragment_size: :optimized,
  ttl_multiplier: 1.0,
  prefetch_enabled: true,
  monitoring_enabled: true,
  max_memory_mb: 8192
```

## Deployment Checklist

### Pre-Launch
- [ ] Load testing with 100k+ requests/second
- [ ] Memory usage profiling under realistic loads
- [ ] Failover testing with backend outages
- [ ] Data integrity validation across all providers
- [ ] Cache hit rate optimization tuning

### Launch Monitoring
- [ ] Real-time cache hit rate dashboards
- [ ] API call reduction tracking vs baseline
- [ ] Response time percentile monitoring
- [ ] Memory usage and fragment count trends
- [ ] Error rate and recovery time tracking

### Post-Launch Optimization
- [ ] Fragment size tuning based on usage patterns
- [ ] TTL optimization based on data volatility
- [ ] Prefetch strategy refinement
- [ ] Provider reliability scoring adjustments

## Success Criteria

**Technical Success**: 
- Cache layer transparent to existing Quant.Explorer users
- 90%+ reduction in external API calls
- Sub-10ms cached response times
- Zero data integrity issues

**Business Success**:
- Support 10x traffic increase without proportional API cost increase
- Enable real-time financial applications
- Provide foundation for advanced features (alerts, streaming, ML)

This cache system will transform your Quant.Explorer API into a high-performance financial data platform capable of supporting the most demanding trading and analytics applications.