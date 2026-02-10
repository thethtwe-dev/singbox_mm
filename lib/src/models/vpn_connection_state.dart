enum VpnConnectionState {
  disconnected,
  preparing,
  connecting,
  connected,
  disconnecting,
  error,
}

extension VpnConnectionStateWire on VpnConnectionState {
  String get wireValue {
    switch (this) {
      case VpnConnectionState.disconnected:
        return 'disconnected';
      case VpnConnectionState.preparing:
        return 'preparing';
      case VpnConnectionState.connecting:
        return 'connecting';
      case VpnConnectionState.connected:
        return 'connected';
      case VpnConnectionState.disconnecting:
        return 'disconnecting';
      case VpnConnectionState.error:
        return 'error';
    }
  }

  bool get isConnected => this == VpnConnectionState.connected;
}

VpnConnectionState vpnConnectionStateFromWire(Object? wireValue) {
  switch (wireValue) {
    case 'disconnected':
      return VpnConnectionState.disconnected;
    case 'preparing':
      return VpnConnectionState.preparing;
    case 'connecting':
      return VpnConnectionState.connecting;
    case 'connected':
      return VpnConnectionState.connected;
    case 'disconnecting':
      return VpnConnectionState.disconnecting;
    case 'error':
      return VpnConnectionState.error;
    default:
      return VpnConnectionState.disconnected;
  }
}
