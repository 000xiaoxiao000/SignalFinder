class DnsServer {
  final String name;
  final String address;
  final String description;
  int latencyMs;
  bool isTested;
  bool isReachable;

  DnsServer({
    required this.name,
    required this.address,
    required this.description,
    this.latencyMs = -1,
    this.isTested = false,
    this.isReachable = false,
  });

  static List<DnsServer> defaultServers() => [
        DnsServer(
            name: '阿里 DNS',
            address: '223.5.5.5',
            description: '阿里云公共 DNS，国内首选'),
        DnsServer(
            name: '腾讯 DNS', address: '119.29.29.29', description: '腾讯云公共 DNS'),
        DnsServer(
            name: '114 DNS',
            address: '114.114.114.114',
            description: '国内老牌公共 DNS'),
        DnsServer(
            name: '百度 DNS', address: '180.76.76.76', description: '百度公共 DNS'),
        DnsServer(
            name: 'Cloudflare', address: '1.1.1.1', description: '国际最快 DNS'),
        DnsServer(
            name: 'Google DNS',
            address: '8.8.8.8',
            description: 'Google 公共 DNS'),
        DnsServer(name: '运营商默认', address: 'auto', description: '由运营商自动分配'),
      ];

  String get latencyLabel {
    if (!isTested) return '未测试';
    if (!isReachable) return '不可达';
    if (latencyMs < 20) return '极快 ${latencyMs}ms';
    if (latencyMs < 50) return '快速 ${latencyMs}ms';
    if (latencyMs < 100) return '良好 ${latencyMs}ms';
    return '较慢 ${latencyMs}ms';
  }

  String get speedLevel {
    if (!isTested || !isReachable) return 'unknown';
    if (latencyMs < 20) return 'excellent';
    if (latencyMs < 50) return 'good';
    if (latencyMs < 100) return 'fair';
    return 'poor';
  }
}
