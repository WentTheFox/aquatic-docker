import socket, struct, os, sys, random
def announce(host, port, ihex, timeout=3):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(timeout)
    tx = random.getrandbits(32)
    s.sendto(struct.pack('>QII', 0x41727101980, 0, tx), (host, port))      # connect
    d, _ = s.recvfrom(2048); act, rtx, cid = struct.unpack('>IIQ', d[:16]); assert act == 0 and rtx == tx, 'bad connect reply'
    tx = random.getrandbits(32)
    req = struct.pack('>QII20s20sQQQIIIiH', cid, 1, tx, bytes.fromhex(ihex), os.urandom(20), 0, 1000, 0, 2, 0, 0, -1, 6881)  # announce, event=started
    s.sendto(req, (host, port))
    d, _ = s.recvfrom(2048); act = struct.unpack('>I', d[:4])[0]
    if act == 1: i, l, se = struct.unpack('>III', d[8:20]); return f'OK announce (interval={i}, leechers={l}, seeders={se})'
    if act == 3: return 'ERROR: ' + d[8:].decode(errors='replace')
    return f'unexpected action {act}'
if __name__ == '__main__':
    print(announce('127.0.0.1', int(sys.argv[1]), sys.argv[2]))
