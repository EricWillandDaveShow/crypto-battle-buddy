// Symbols the price layer is allowed to poll across feeds.
// NOTE: Tier execution remains BTC/ETH/SOL only (UI doctrine).
const supportedSymbols = <String>{
  'BTC',
  'ETH',
  'SOL',
  'STX',
};

// CoinGecko "id" values for /simple/price.
// STX on CoinGecko is "stacks" (not "STX").
const coingeckoIdBySymbol = <String, String>{
  'BTC': 'bitcoin',
  'ETH': 'ethereum',
  'SOL': 'solana',
  'STX': 'stacks',
};

const binancePairBySymbol = <String, String>{
  'BTC': 'BTCUSDT',
  'ETH': 'ETHUSDT',
  'SOL': 'SOLUSDT',
  'STX': 'STXUSDT',
};

const krakenPairBySymbol = <String, String>{
  'BTC': 'XBTUSD',
  'ETH': 'ETHUSD',
  'SOL': 'SOLUSD',
  // If Kraken feed does not support it, fetch will simply skip it (guarded by map lookup).
  'STX': 'STXUSD',
};
