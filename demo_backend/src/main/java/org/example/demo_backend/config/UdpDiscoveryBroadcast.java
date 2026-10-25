package org.example.demo_backend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.Enumeration;

/**
 * 启动后定期向局域网 UDP 广播自身地址，供 App 自动发现。
 * 广播格式：WORDFS:<ip>:<port>
 */
@Component
public class UdpDiscoveryBroadcast implements CommandLineRunner {

    private static final int DISCOVERY_PORT = 9999;
    private static final String SERVICE_TAG = "WORDFS";
    private static final long BROADCAST_INTERVAL_MS = 10000;
    private static boolean firstBroadcastLogged = false;

    @Value("${server.port:8080}")
    private int serverPort;

    @Override
    public void run(String... args) {
        Thread broadcastThread = new Thread(() -> {
            while (true) {
                try {
                    String localIp = getLocalLanIp();
                    String message = SERVICE_TAG + ":" + localIp + ":" + serverPort;

                    try (DatagramSocket socket = new DatagramSocket()) {
                        socket.setBroadcast(true);
                        byte[] buffer = message.getBytes("UTF-8");
                        InetAddress broadcastAddr = InetAddress.getByName("255.255.255.255");
                        DatagramPacket packet = new DatagramPacket(buffer, buffer.length, broadcastAddr, DISCOVERY_PORT);
                        socket.send(packet);
                        if (!firstBroadcastLogged) {
                            System.out.println("[Discovery] Broadcast started: " + message);
                            firstBroadcastLogged = true;
                        }
                    }

                    Thread.sleep(BROADCAST_INTERVAL_MS);
                } catch (Exception e) {
                    System.err.println("[Discovery] Broadcast error: " + e.getMessage());
                    try {
                        Thread.sleep(BROADCAST_INTERVAL_MS);
                    } catch (InterruptedException ignored) {
                        Thread.currentThread().interrupt();
                    }
                }
            }
        }, "udp-discovery-broadcast");
        broadcastThread.setDaemon(true);
        broadcastThread.start();
    }

    /**
     * 获取本机局域网 IP（非回环、非虚拟网卡优先）
     */
    private String getLocalLanIp() {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface ni = interfaces.nextElement();
                if (!ni.isUp() || ni.isLoopback() || ni.isVirtual()) {
                    continue;
                }
                Enumeration<InetAddress> addrs = ni.getInetAddresses();
                while (addrs.hasMoreElements()) {
                    InetAddress addr = addrs.nextElement();
                    String ip = addr.getHostAddress();
                    // 只取 IPv4，排除回环和链路本地地址
                    if (!ip.startsWith("127.") && !ip.startsWith("169.254.") && !ip.contains(":")) {
                        return ip;
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("[Discovery] Get local IP error: " + e.getMessage());
        }
        return "127.0.0.1";
    }
}
