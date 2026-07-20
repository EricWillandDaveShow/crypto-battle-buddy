enum CryptoAsset {
  btc(symbol: 'BTC', name: 'Bitcoin', iconText: '₿'),
  eth(symbol: 'ETH', name: 'Ethereum', iconText: 'Ξ'),
  sol(symbol: 'SOL', name: 'Solana', iconText: '◎'),
  stx(symbol: 'STX', name: 'Stacks', iconText: 'S'),
  axl(symbol: 'AXL', name: 'Axelar', iconText: 'A'),
  near(symbol: 'NEAR', name: 'NEAR', iconText: 'N');

  final String symbol;
  final String name;
  final String iconText;

  const CryptoAsset({
    required this.symbol,
    required this.name,
    required this.iconText,
  });
}
