"""Persist a credential-free filming desktop in the pinned Tahoe image."""
import json
from pathlib import Path
import time
import uuid

root = Path.home() / 'Library/DoNotDisturb/DB'
now = time.time() - 978307200  # Apple's reference date: 2001-01-01.
source = {'assertionClientIdentifier': 'com.apple.focus.activity-manager'}
record = {
    'assertionUUID': str(uuid.uuid4()).upper(),
    'assertionSource': source,
    'assertionStartDateTimestamp': now,
    'assertionDetails': {
        'assertionDetailsIdentifier': 'com.apple.donotdisturb.kit.lifetime.one-hour',
        'assertionDetailsModeIdentifier': 'com.apple.donotdisturb.mode.default',
        'assertionDetailsLifetime': {
            'assertionDetailsLifetimeType': 'date-interval',
            'assertionDetailsDateIntervalLifetimeStartDateTimestamp': now,
            'assertionDetailsDateIntervalLifetimeEndDateTimestamp': 3092601600,  # 2099-01-01.
        },
        'assertionDetailsReason': 'user-action',
    },
}
(root / 'Assertions.json').write_text(json.dumps({
    'data': [{'storeAssertionRecords': [record]}],
    'header': {'version': 8, 'timestamp': now},
}))
p = root / 'ModeConfigurations.json'
s = json.loads(p.read_text())
for data in s['data']:
    mode = data['modeConfigurations']['com.apple.donotdisturb.mode.default']
    mode['configuration']['allowIntelligentManagement'] = 0
p.write_text(json.dumps(s))
