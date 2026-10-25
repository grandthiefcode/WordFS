import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

const DISCOVERY_PORT: number = 9999;
const SERVICE_TAG: string = 'WORDFS';
const DEFAULT_TIMEOUT_MS: number = 5000;
const EMULATOR_FALLBACK: string = 'http://10.0.2.2:8080';

export function discoverServer(timeoutMs: number = DEFAULT_TIMEOUT_MS): Promise<string> {
  return new Promise((resolve: (url: string) => void) => {
    let resolved: boolean = false;
    let udpSocket: socket.UDPSocket = socket.constructUDPSocketInstance();
    let textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');

    const cleanup = (): void => {
      try {
        udpSocket.off('message');
        udpSocket.close();
      } catch (e) {
        const err = e as BusinessError;
        console.error('[ServerDiscovery] cleanup error: ' + err.message);
      }
    };

    const finish = (url: string): void => {
      if (resolved) {
        return;
      }
      resolved = true;
      cleanup();
      resolve(url);
    };

    udpSocket.on('message', (info: socket.SocketMessageInfo) => {
      try {
        const message: string = textDecoder.decodeToString(new Uint8Array(info.message));
        if (message.startsWith(SERVICE_TAG + ':')) {
          const parts: string[] = message.split(':');
          if (parts.length >= 3) {
            const ip: string = parts[1];
            const port: string = parts[2];
            const url: string = 'http://' + ip + ':' + port;
            console.info('[ServerDiscovery] Found server: ' + url);
            finish(url);
          }
        }
      } catch (e) {
        const err = e as BusinessError;
        console.error('[ServerDiscovery] parse error: ' + err.message);
      }
    });

    udpSocket.bind({ address: '0.0.0.0', port: DISCOVERY_PORT }).then(() => {
      console.info('[ServerDiscovery] Listening on port ' + DISCOVERY_PORT);
    }).catch((err: BusinessError) => {
      console.error('[ServerDiscovery] Bind failed: ' + err.message);
      finish(EMULATOR_FALLBACK);
    });

    setTimeout(() => {
      if (!resolved) {
        console.info('[ServerDiscovery] Timeout, using fallback: ' + EMULATOR_FALLBACK);
        finish(EMULATOR_FALLBACK);
      }
    }, timeoutMs);
  });
}
