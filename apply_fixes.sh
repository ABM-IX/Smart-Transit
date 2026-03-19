#!/usr/bin/env bash
# =============================================================
#  Smart Transit — apply all recommended UI fixes
#  Usage:  bash apply_fixes.sh [path/to/Smart-Transit]
#  If no path is given, assumes you're already inside the repo.
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()     { echo -e "${GREEN}  ✓  ${RESET}$*"; }
fail()   { echo -e "${RED}  ✗  ${RESET}$*"; exit 1; }
info()   { echo -e "${CYAN}  →  ${RESET}$*"; }
warn()   { echo -e "${YELLOW}  !  ${RESET}$*"; }
banner() { echo -e "\n${BOLD}${CYAN}━━  $*  ━━${RESET}"; }

# ── Resolve repo root ─────────────────────────────────────────
REPO="${1:-.}"
cd "$REPO" || fail "Cannot cd into '$REPO'"

DRIVER="SmartTransit/app/src/main/java/com/example/smarttransit/ui/driver/DriverDashboard.kt"
PASSENGER="SmartTransit/app/src/main/java/com/example/smarttransit/ui/passenger/PassengerDashboard.kt"
DASHBOARD="dashboard/index.html"

banner "Smart Transit — Fix Script"
echo   "  Repo     : $(pwd)"
echo   "  Patching :"
echo   "    · $DRIVER"
echo   "    · $PASSENGER"
echo   "    · $DASHBOARD"
echo

for f in "$DRIVER" "$PASSENGER" "$DASHBOARD"; do
  [[ -f "$f" ]] || fail "File not found: $f  (run from the repo root, or pass the path as an argument)"
done
ok "All target files found"

# ── Backup ────────────────────────────────────────────────────
BACKUP_DIR=".fix_backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$DRIVER"    "$BACKUP_DIR/DriverDashboard.kt"
cp "$PASSENGER" "$BACKUP_DIR/PassengerDashboard.kt"
cp "$DASHBOARD" "$BACKUP_DIR/index.html"
ok "Originals backed up → $BACKUP_DIR"

# =============================================================
#  FIX 1 — dashboard/index.html
#  Falsy check !data.coords.lat silently drops any driver whose
#  GPS latitude is exactly 0 (valid equatorial coordinate,
#  falsy in JS).  Replace with a strict null check.
# =============================================================
banner "Fix 1 · dashboard/index.html — safe lat=0 guard"

if grep -q "if (!data\.coords || !data\.coords\.lat) return;" "$DASHBOARD"; then
  sed -i 's/if (!data\.coords || !data\.coords\.lat) return;/if (!data.coords || data.coords.lat == null) return;/g' "$DASHBOARD"
  ok "Replaced falsy lat check with null-safe check"
elif grep -q "if (!data\.coords || data\.coords\.lat == null) return;" "$DASHBOARD"; then
  warn "Fix 1 already applied — skipping"
else
  warn "Pattern not found at line ~746 — dashboard may differ. Check manually:\n    if (!data.coords || !data.coords.lat) return;"
fi

# =============================================================
#  FIX 2 — PassengerDashboard.kt
#  Gate the Confirm Boarding button so it stays disabled until
#  a driver has actually accepted the hail.
#  Changes:
#    a) Call site → passes hailAcceptedDriverId != null
#    b) Function signature → adds hailAccepted: Boolean param
#    c) OutlinedButton → enabled = hailAccepted, dynamic label
# =============================================================
banner "Fix 2 · PassengerDashboard.kt — gate Confirm Boarding button"

# 2a — call site
OLD_CALL='BusCombiActions(mode, boarded, route.routeId, passengerId, userLocation, isHailing, { next ->'
NEW_CALL='BusCombiActions(mode, boarded, route.routeId, passengerId, userLocation, isHailing, hailAcceptedDriverId != null, { next ->'

if grep -qF "$OLD_CALL" "$PASSENGER"; then
  sed -i "s|${OLD_CALL}|${NEW_CALL}|g" "$PASSENGER"
  ok "Call site — hailAcceptedDriverId != null added"
elif grep -qF "$NEW_CALL" "$PASSENGER"; then
  warn "Fix 2a already applied — skipping call site"
else
  warn "Fix 2a: call site pattern not found. Patch BusCombiActions() call manually."
fi

# 2b — function signature
OLD_SIG='fun BusCombiActions(m: TransportMode, boarded: Boolean, rid: String, pid: String, loc: LatLng?, hailing: Boolean, onH: (Boolean) -> Unit, onB: () -> Unit)'
NEW_SIG='fun BusCombiActions(m: TransportMode, boarded: Boolean, rid: String, pid: String, loc: LatLng?, hailing: Boolean, hailAccepted: Boolean, onH: (Boolean) -> Unit, onB: () -> Unit)'

if grep -qF "$OLD_SIG" "$PASSENGER"; then
  sed -i "s|${OLD_SIG}|${NEW_SIG}|g" "$PASSENGER"
  ok "Function signature — hailAccepted: Boolean added"
elif grep -qF "hailAccepted: Boolean, onH:" "$PASSENGER"; then
  warn "Fix 2b already applied — skipping signature"
else
  warn "Fix 2b: signature pattern not found. Add hailAccepted: Boolean to BusCombiActions() manually."
fi

# 2c — button body (python handles multi-line replacement cleanly)
python3 - "$PASSENGER" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()

OLD = (
    '        OutlinedButton(\n'
    '            onClick = onB,\n'
    '            modifier = Modifier.fillMaxWidth().height(48.dp),\n'
    '            shape = RoundedCornerShape(14.dp)\n'
    '        ) {\n'
    '            Icon(Icons.Default.DirectionsBus, null, modifier = Modifier.size(18.dp))\n'
    '            Spacer(Modifier.width(6.dp))\n'
    '            Text("Confirm Boarding")\n'
    '        }'
)
NEW = (
    '        OutlinedButton(\n'
    '            onClick = onB,\n'
    '            enabled = hailAccepted,\n'
    '            modifier = Modifier.fillMaxWidth().height(48.dp),\n'
    '            shape = RoundedCornerShape(14.dp),\n'
    '            colors = ButtonDefaults.outlinedButtonColors(\n'
    '                contentColor = if (hailAccepted) MaterialTheme.colorScheme.primary else Color.Gray,\n'
    '                disabledContentColor = Color.Gray\n'
    '            )\n'
    '        ) {\n'
    '            Icon(Icons.Default.DirectionsBus, null, modifier = Modifier.size(18.dp))\n'
    '            Spacer(Modifier.width(6.dp))\n'
    '            Text(if (hailAccepted) "Confirm Boarding" else "Waiting for driver\u2026")\n'
    '        }'
)

if OLD in src:
    src = src.replace(OLD, NEW, 1)
    with open(path, 'w') as f:
        f.write(src)
    print("  \033[0;32m  \u2713  \033[0m Boarding button gated — disabled + label changes until driver accepts")
elif 'enabled = hailAccepted' in src:
    print("  \033[1;33m  !  \033[0m Fix 2c already applied \u2014 skipping button body")
else:
    print("  \033[1;33m  !  \033[0m Fix 2c pattern not found \u2014 add enabled = hailAccepted to OutlinedButton manually")
PYEOF

# =============================================================
#  FIX 3 — PassengerDashboard.kt
#  TripHistoryScreen: replace hardcoded "Today / Yesterday /
#  Mar 17" strings with dynamic java.time.LocalDate so the
#  dates are always correct regardless of when the app opens.
# =============================================================
banner "Fix 3 · PassengerDashboard.kt — dynamic trip history dates"

python3 - "$PASSENGER" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()

OLD = (
    '    val mockTrips = remember {\n'
    '        listOf(\n'
    '            Triple("Bus Rank \u2192 Francistown", "Today 14:30", "P8.00"),\n'
    '            Triple("BAC \u2192 Main Mall", "Today 08:15", "P8.00"),\n'
    '            Triple("Taxi to Riverwalk", "Yesterday 18:45", "P15.00"),\n'
    '            Triple("UB \u2192 Bus Rank", "Yesterday 07:20", "P8.00"),\n'
    '            Triple("Taxi to Airport", "Mar 17 06:00", "P45.00")\n'
    '        )\n'
    '    }'
)
NEW = (
    '    val mockTrips = remember {\n'
    '        val today = java.time.LocalDate.now()\n'
    '        val yesterday = today.minusDays(1)\n'
    '        val twoDaysAgo = today.minusDays(2)\n'
    '        val fmt = java.time.format.DateTimeFormatter.ofPattern("MMM d")\n'
    '        listOf(\n'
    '            Triple("Bus Rank \u2192 Francistown", "${today.format(fmt)}, 14:30", "P8.00"),\n'
    '            Triple("BAC \u2192 Main Mall", "${today.format(fmt)}, 08:15", "P8.00"),\n'
    '            Triple("Taxi to Riverwalk", "${yesterday.format(fmt)}, 18:45", "P15.00"),\n'
    '            Triple("UB \u2192 Bus Rank", "${yesterday.format(fmt)}, 07:20", "P8.00"),\n'
    '            Triple("Taxi to Airport", "${twoDaysAgo.format(fmt)}, 06:00", "P45.00")\n'
    '        )\n'
    '    }'
)

if OLD in src:
    src = src.replace(OLD, NEW, 1)
    with open(path, 'w') as f:
        f.write(src)
    print("  \033[0;32m  \u2713  \033[0m Trip history dates now computed from LocalDate.now() \u2014 always fresh")
elif 'java.time.LocalDate.now()' in src:
    print("  \033[1;33m  !  \033[0m Fix 3 already applied \u2014 skipping")
else:
    print("  \033[1;33m  !  \033[0m Fix 3 pattern not found \u2014 replace mockTrips manually with LocalDate.now()")
PYEOF

# =============================================================
#  FIX 4 — DriverDashboard.kt
#  Taxi hail card shows raw lat/lng coordinates for pickup and
#  destination. Add a reverseGeocode() Nominatim helper and
#  state vars so the card resolves to a readable street address.
# =============================================================
banner "Fix 4 · DriverDashboard.kt — reverse geocoding on hail card"

python3 - "$DRIVER" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()

GEOCODE_FN = '''\
fun reverseGeocode(lat: Double, lng: Double, onResult: (String) -> Unit) {
    kotlinx.coroutines.GlobalScope.launch(kotlinx.coroutines.Dispatchers.IO) {
        try {
            val url = java.net.URL("https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=16&addressdetails=1")
            val conn = url.openConnection() as java.net.HttpURLConnection
            conn.setRequestProperty("User-Agent", "SmartTransit/1.0")
            conn.connectTimeout = 3000
            conn.readTimeout = 3000
            val body = conn.inputStream.bufferedReader().readText()
            val obj = org.json.JSONObject(body)
            val address = obj.optJSONObject("address")
            val label = when {
                address?.has("road") == true && address.has("suburb") ->
                    "${address.optString("road")}, ${address.optString("suburb")}"
                address?.has("road") == true ->
                    "${address.optString("road")}, ${address.optString("city", address.optString("town", ""))}"
                else -> obj.optString("display_name", "").split(",").take(2).joinToString(", ")
            }
            withContext(kotlinx.coroutines.Dispatchers.Main) { onResult(label.trim().trimEnd(',')) }
        } catch (_: Exception) {
            withContext(kotlinx.coroutines.Dispatchers.Main) {
                onResult("${String.format("%.4f", lat)}, ${String.format("%.4f", lng)}")
            }
        }
    }
}

'''

MARKER = '@Composable\nfun TaxiDriverActions('

if 'fun reverseGeocode(' not in src:
    idx = src.find(MARKER)
    if idx != -1:
        src = src[:idx] + GEOCODE_FN + src[idx:]
        print("  \033[0;32m  \u2713  \033[0m reverseGeocode() helper injected above TaxiDriverActions")
    else:
        print("  \033[1;33m  !  \033[0m Could not find TaxiDriverActions marker \u2014 add reverseGeocode() manually")
else:
    print("  \033[1;33m  !  \033[0m reverseGeocode() already present \u2014 skipping helper injection")

OLD_STATE = (
    '    var activeTaxiTripId by remember { mutableStateOf<String?>(null) }\n'
    '    var passengerCount by remember { mutableIntStateOf(1) }\n'
    '    var revenue by remember { mutableIntStateOf(0) }\n'
    '    var totalEarnings by remember { mutableIntStateOf(0) }\n'
    '    var tripsCompleted by remember { mutableIntStateOf(0) }'
)
NEW_STATE = (
    '    var activeTaxiTripId by remember { mutableStateOf<String?>(null) }\n'
    '    var passengerCount by remember { mutableIntStateOf(1) }\n'
    '    var revenue by remember { mutableIntStateOf(0) }\n'
    '    var totalEarnings by remember { mutableIntStateOf(0) }\n'
    '    var tripsCompleted by remember { mutableIntStateOf(0) }\n'
    '    var pickupAddress by remember { mutableStateOf("Locating\u2026") }\n'
    '    var destinationAddress by remember { mutableStateOf("Locating\u2026") }\n'
    '\n'
    '    val latestHailForGeo = hails.lastOrNull()\n'
    '    LaunchedEffect(latestHailForGeo?.optString("passengerId")) {\n'
    '        pickupAddress = "Locating\u2026"\n'
    '        destinationAddress = "Locating\u2026"\n'
    '        latestHailForGeo?.optJSONObject("pickupLoc")?.let { loc ->\n'
    '            reverseGeocode(loc.optDouble("lat"), loc.optDouble("lng")) { pickupAddress = it }\n'
    '        }\n'
    '        latestHailForGeo?.optJSONObject("destinationLoc")?.let { loc ->\n'
    '            reverseGeocode(loc.optDouble("lat"), loc.optDouble("lng")) { destinationAddress = it }\n'
    '        }\n'
    '    }'
)

if 'var pickupAddress' not in src and OLD_STATE in src:
    src = src.replace(OLD_STATE, NEW_STATE, 1)
    print("  \033[0;32m  \u2713  \033[0m Address state vars + LaunchedEffect added to TaxiDriverActions")
elif 'var pickupAddress' in src:
    print("  \033[1;33m  !  \033[0m Address state already present \u2014 skipping state injection")
else:
    print("  \033[1;33m  !  \033[0m State pattern not found \u2014 add pickupAddress / destinationAddress vars manually")

# Normalise CRLF -> LF and write, then use sed for the coord lines
# (avoids all heredoc/shell escaping issues with Kotlin string templates)
src = src.replace('\r\n', '\n')
with open(path, 'w') as f:
    f.write(src)
print("  \033[0;36m  \u2192  \033[0m File written — sed will handle coord line replacements")
PYEOF

# 4d — sed replaces the two coord Text() lines (no heredoc escaping issues)
PICKUP_RAW='Text("${pickup.optDouble("lat", 0.0).let { String.format("%.4f", it) }}, ${pickup.optDouble("lng", 0.0).let { String.format("%.4f", it) }}", fontSize = 13.sp, fontWeight = FontWeight.Medium)'
DEST_RAW='Text("${destination.optDouble("lat", 0.0).let { String.format("%.4f", it) }}, ${destination.optDouble("lng", 0.0).let { String.format("%.4f", it) }}", fontSize = 13.sp, fontWeight = FontWeight.Medium)'

if grep -qF "$PICKUP_RAW" "$DRIVER"; then
  sed -i "s|${PICKUP_RAW}|Text(pickupAddress, fontSize = 13.sp, fontWeight = FontWeight.Medium)|g" "$DRIVER"
  ok "Hail card pickup line replaced with pickupAddress"
elif grep -q "Text(pickupAddress" "$DRIVER"; then
  warn "Fix 4d pickup already applied — skipping"
else
  warn "Fix 4d: pickup coord Text() not found — replace manually"
fi

if grep -qF "$DEST_RAW" "$DRIVER"; then
  sed -i "s|${DEST_RAW}|Text(destinationAddress, fontSize = 13.sp, fontWeight = FontWeight.Medium)|g" "$DRIVER"
  ok "Hail card destination line replaced with destinationAddress"
elif grep -q "Text(destinationAddress" "$DRIVER"; then
  warn "Fix 4d destination already applied — skipping"
else
  warn "Fix 4d: destination coord Text() not found — replace manually"
fi

# =============================================================
#  Summary
# =============================================================
banner "All fixes applied"
echo -e "  Backups saved to : ${BOLD}$BACKUP_DIR/${RESET}"
echo
echo -e "  ${BOLD}Verify the fixes:${RESET}"
echo    "  1.  ./gradlew assembleDebug"
echo    "  2.  Taxi hail card   → should show street address, not coordinates"
echo    "  3.  Boarding button  → greyed out / 'Waiting for driver…' until accepted"
echo    "  4.  Trip history     → dates match today (no hardcoded 'Mar 17')"
echo    "  5.  Admin dashboard  → open in browser, confirm driver pins work at lat=0"
echo
echo -e "  ${BOLD}To undo all changes:${RESET}"
echo    "  cp $BACKUP_DIR/DriverDashboard.kt  $DRIVER"
echo    "  cp $BACKUP_DIR/PassengerDashboard.kt $PASSENGER"
echo    "  cp $BACKUP_DIR/index.html           $DASHBOARD"
echo
