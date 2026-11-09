#!/bin/bash
# Runs Flow for Omarchy's pipeline against a local mock provider. No microphone,
# network, clipboard or real API key is used.

set -u
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
port=$((20000 + RANDOM % 20000))
trap 'kill $server 2>/dev/null; rm -rf "$work"' EXIT

export XDG_CONFIG_HOME=$work/config XDG_STATE_HOME=$work/state XDG_RUNTIME_DIR=$work/run
mkdir -p "$XDG_CONFIG_HOME/flow-omarchy" "$XDG_RUNTIME_DIR" "$work/mock"
unset GROQ_API_KEY
cat > "$XDG_CONFIG_HOME/flow-omarchy/config" <<CONF
FLOW_API_KEY="test-key"
FLOW_API_URL="http://127.0.0.1:$port/v1/"
FLOW_OUTPUT="stdout"
FLOW_NOTIFY=0
FLOW_TIMEOUT=5
CONF
printf 'Dana\nkubectl\n' > "$XDG_CONFIG_HOME/flow-omarchy/vocabulary"

python3 -I "$root/test/mock_server.py" "$work/mock" "$port" &
server=$!
for _ in $(seq 50); do curl -s "http://127.0.0.1:$port/" >/dev/null && break; sleep 0.1; done

ffmpeg -loglevel error -f lavfi -i "sine=frequency=440:duration=1" -ar 16000 -ac 1 -c:a pcm_s16le "$work/tone.wav"
ffmpeg -loglevel error -f lavfi -i "sine=frequency=440:duration=0.1" -ar 16000 -ac 1 -c:a pcm_s16le "$work/tap.wav"

passed=0 failed=0
check() {
  if [[ $2 == "$3" ]]; then
    passed=$((passed + 1)); echo "ok   $1"
  else
    failed=$((failed + 1)); echo "FAIL $1"; echo "     expected: $3"; echo "     got:      $2"
  fi
}

# Feeds a recorded file through the same _process path that `stop` uses.
run_pipeline() {
  local wav=$1 session
  echo "$2" > "$work/mock/scenario"
  : > "$work/mock/requests.jsonl"
  session=$(mktemp -d "$XDG_RUNTIME_DIR/flow-omarchy/session-XXXXXX")
  cp "$wav" "$session/audio.wav"
  echo '{"class":"thunderbird","title":"Write: Sync with Dana","tags":[]}' > "$session/window.json"
  touch "$session/processing"
  "$root/bin/flow-omarchy" _process "$session" 2>/dev/null
}

mkdir -p "$XDG_RUNTIME_DIR/flow-omarchy"
cleaned="Hey Dana, can we move the sync to Wednesday?"
raw="um so hey dana comma can we move the sync to thursday no actually wednesday"

check "cleans the transcript" "$(run_pipeline "$work/tone.wav" ok)" "$cleaned"
req=$(sed -n 2p "$work/mock/requests.jsonl")
check "sends the API key as a bearer header" "$(jq -r .auth <<< "$req")" "Bearer test-key"
check "uses the default cleanup model" "$(jq -r .body.model <<< "$req")" "openai/gpt-oss-20b"
check "uses low reasoning effort for gpt-oss-20b" "$(jq -r .body.reasoning_effort <<< "$req")" "low"
check "sends the window as context" "$(jq -r '.body.messages[1].content | test("CONTEXT: \"The user is dictating into the app \\\"thunderbird\\\"")' <<< "$req")" "true"
check "sends the vocabulary" "$(jq -r '.body.messages[0].content | test("exactly in the output when relevant:\nDana, kubectl")' <<< "$req")" "true"
check "uses FreeFlow's cleanup prompt" "$(jq -r '.body.messages[0].content | startswith("You are a literal dictation cleanup layer")' <<< "$req")" "true"
check "requests Whisper large v3" "$(sed -n 1p "$work/mock/requests.jsonl" | jq -r .body.model)" "whisper-large-v3"
check "remembers the last transcript" "$(cat "$XDG_STATE_HOME/flow-omarchy/last.txt")" "$cleaned"
check "removes the session afterwards" "$(compgen -G "$XDG_RUNTIME_DIR/flow-omarchy/session-*" | wc -l)" "0"

check "falls back to the second model" "$(run_pipeline "$work/tone.wav" primary-fails)" "$cleaned"
check "fallback model is qwen" "$(sed -n 3p "$work/mock/requests.jsonl" | jq -r .body.model)" "qwen/qwen3.8-27b"
check "strips think tags and quotes" "$(run_pipeline "$work/tone.wav" think)" "$cleaned"
check "rejects an answered instruction, pastes raw" "$(run_pipeline "$work/tone.wav" answers-instruction)" "$raw"
check "EMPTY pastes nothing" "$(run_pipeline "$work/tone.wav" empty)" ""
check "silence pastes nothing" "$(run_pipeline "$work/tone.wav" silence)" ""
check "an accidental tap is not sent" "$(run_pipeline "$work/tap.wav" ok; wc -l < "$work/mock/requests.jsonl")" "0"
run_pipeline "$work/tone.wav" transcribe-fails >/dev/null; status=$?
check "transcription errors fail" "$status" "1"

# Language settings use FreeFlow's wording.
sed -i 's/^FLOW_LANGUAGE=.*//' "$XDG_CONFIG_HOME/flow-omarchy/config"
echo 'FLOW_LANGUAGE="zh"' >> "$XDG_CONFIG_HOME/flow-omarchy/config"
run_pipeline "$work/tone.wav" ok >/dev/null
req=$(sed -n 2p "$work/mock/requests.jsonl")
check "dictation language goes to Whisper" "$(sed -n 1p "$work/mock/requests.jsonl" | jq -r .body.language)" "zh"
check "dictation language goes to cleanup" "$(jq -r '.body.messages[0].content | test("The dictation is primarily in zh\\. Write the cleaned text in zh\\. Preserve mixed-language")' <<< "$req")" "true"
echo 'FLOW_OUTPUT_LANGUAGE="English"' >> "$XDG_CONFIG_HOME/flow-omarchy/config"
run_pipeline "$work/tone.wav" ok >/dev/null
req=$(sed -n 2p "$work/mock/requests.jsonl")
check "output language asks for a translation" "$(jq -r '.body.messages[0].content | test("Translate the final cleaned text into English\\. Output ONLY in English")' <<< "$req")" "true"

sed -i 's/^FLOW_API_KEY=.*/FLOW_API_KEY=""/' "$XDG_CONFIG_HOME/flow-omarchy/config"
echo "test-key" | "$root/bin/flow-omarchy" setup >/dev/null 2>&1; status=$?
check "setup saves and verifies the key" "$status:$(grep -c '^FLOW_API_KEY="test-key"' "$XDG_CONFIG_HOME/flow-omarchy/config")" "0:1"
check "doctor confirms the key" "$("$root/bin/flow-omarchy" doctor | grep -c '^ok   API key accepted')" "1"
check "config is private" "$(stat -c %a "$XDG_CONFIG_HOME/flow-omarchy/config")" "600"
echo "wrong-key" | "$root/bin/flow-omarchy" setup >/dev/null 2>&1; status=$?
check "setup rejects a bad key" "$status" "1"

check "status is idle" "$("$root/bin/flow-omarchy" status)" "idle"
check "stop when idle is a no-op" "$("$root/bin/flow-omarchy" stop; echo $?)" "0"

# Recording lifecycle with a stand-in for pw-record (no microphone is opened).
mkdir -p "$work/fakebin"
cat > "$work/fakebin/pw-record" <<FAKE
#!/bin/bash
trap 'cp "$work/tone.wav" "\${@: -1}"; exit 0' INT
while :; do sleep 0.05; done
FAKE
chmod +x "$work/fakebin/pw-record"
sed -i 's/^FLOW_OUTPUT=.*/FLOW_OUTPUT="stdout"/' "$XDG_CONFIG_HOME/flow-omarchy/config"
echo ok > "$work/mock/scenario"; : > "$work/mock/requests.jsonl"
PATH="$work/fakebin:$PATH" "$root/bin/flow-omarchy" toggle
sleep 0.3
check "toggle starts recording" "$("$root/bin/flow-omarchy" status)" "recording"
PATH="$work/fakebin:$PATH" "$root/bin/flow-omarchy" start
check "start while recording keeps one recorder" "$(pgrep -fc "$work/fakebin/pw-record")" "1"
PATH="$work/fakebin:$PATH" "$root/bin/flow-omarchy" toggle
for _ in $(seq 50); do [[ $("$root/bin/flow-omarchy" status) == idle ]] && break; sleep 0.1; done
check "toggle stops and processes in the background" "$("$root/bin/flow-omarchy" status):$(wc -l < "$work/mock/requests.jsonl")" "idle:2"
check "background run saved the result" "$(cat "$XDG_STATE_HOME/flow-omarchy/last.txt")" "$cleaned"
PATH="$work/fakebin:$PATH" "$root/bin/flow-omarchy" start; sleep 0.2
: > "$work/mock/requests.jsonl"
"$root/bin/flow-omarchy" cancel
sleep 0.3
check "cancel discards the recording" "$("$root/bin/flow-omarchy" status):$(wc -l < "$work/mock/requests.jsonl"):$(compgen -G "$XDG_RUNTIME_DIR/flow-omarchy/session-*" | wc -l)" "idle:0:0"
check "no recorder left running" "$(pgrep -fc "$work/fakebin/pw-record")" "0"

echo "$passed passed, $failed failed"
((failed == 0))
