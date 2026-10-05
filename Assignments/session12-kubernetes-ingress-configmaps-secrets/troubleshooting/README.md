# Task 5: Troubleshooting Root Cause Analysis (RCA) — The Trailing Newline Secret Bug

## 1. Problem Identification

### Incident Summary
- **Service Affected:** `yatri-backend` pod connecting to `postgresql` database.
- **Symptom:** Application pods crashed or failed startup with the following log:
  ```text
  FATAL: password authentication failed for user "yatri_admin"
  ```
- **Developer Statement:**
  > *"I verified that the password is correct! In my secret YAML, I generated the base64 value by running: `echo "secretpassword" | base64`."*

---

## 2. Troubleshooting Commands Executed

To investigate the issue, we analyzed the raw byte stream and compared Base64 generation methods:

```bash
# Step 1: Inspect the standard echo byte output in hex
echo "secretpassword" | xxd

# Step 2: Compare base64 output of echo vs echo -n
echo "secretpassword" | base64
echo -n "secretpassword" | base64

# Step 3: Decode and verify length and special characters using Python
python -c "import base64; b = base64.b64decode('c2VjcmV0cGFzc3dvcmQK'); print('Before (with echo):', repr(b), 'Length:', len(b))"
python -c "import base64; b = base64.b64decode('c2VjcmV0cGFzc3dvcmQ='); print('After  (with echo -n):', repr(b), 'Length:', len(b))"
```

---

## 3. Root Cause Analysis

1. **The Hidden Character:**
   Standard Linux `echo` automatically appends a newline character (`\n` / ASCII `0x0A`) at the end of the string.
   As seen in the `xxd` output:
   ```text
   00000000: 7365 6372 6574 7061 7373 776f 7264 0a    secretpassword.
   ```
   The last byte `0a` represents `\n`.

2. **The Base64 Encoding Discrepancy:**
   - With newline: `c2VjcmV0cGFzc3dvcmQK` (Encodes 15 bytes: `secretpassword\n`).
   - Without newline: `c2VjcmV0cGFzc3dvcmQ=` (Encodes 14 bytes: `secretpassword`).

3. **Authentication Rejection:**
   When the Kubernetes pod injected the secret into its environment, the application passed `b'secretpassword\n'` (length 15) to the PostgreSQL database instead of the expected `b'secretpassword'` (length 14). Because the passwords did not match, PostgreSQL rejected the authentication.

---

## 4. The Fix & Resolution

Always use the `-n` flag with `echo` to suppress the trailing newline character:

```bash
echo -n "secretpassword" | base64
# Output: c2VjcmV0cGFzc3dvcmQ=
```

Update `db-secret.yaml` with the clean Base64 string:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: yatri-db-secret
type: Opaque
data:
  POSTGRES_PASSWORD: c2VjcmV0cGFzc3dvcmQ=
```

---

## 5. Before & After Verification

| Metric | Before Fix (`echo`) | After Fix (`echo -n`) |
| :--- | :--- | :--- |
| **Command** | `echo "secretpassword" \| base64` | `echo -n "secretpassword" \| base64` |
| **Base64 String** | `c2VjcmV0cGFzc3dvcmQK` | `c2VjcmV0cGFzc3dvcmQ=` |
| **Decoded Value** | `b'secretpassword\n'` | `b'secretpassword'` |
| **Byte Length** | 15 bytes | 14 bytes |
| **Database Auth** | ❌ FAILED (`FATAL: password authentication failed`) | ✅ SUCCESS |

![Troubleshooting Before and After](../screenshot/09-troubleshooting-before-after.png)
