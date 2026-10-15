"""Exercise the public vm commands against host-tool shims, without nested guests."""
import contextlib
import json
import os
from pathlib import Path
import subprocess
import signal
import select
import sys
import tempfile
import unittest

VM = Path(__file__).resolve().parents[1] / '.claude/skills/vm/vm'

SHIM = r'''import fcntl, json, os, pathlib, sys, time
root = pathlib.Path(os.environ['VM_TEST_STATE'])
tool = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / 'state.json').open('r+') as f:
    fcntl.flock(f, fcntl.LOCK_EX)
    state = json.load(f)
    state['calls'].append([tool, *args])
    result, code = '', 0
    guests = state['guests']
    if tool == 'sysctl':
        result = str(state['cores'] if args[-1] == 'hw.ncpu' else state['memory'])
    elif tool == 'tart':
        verb = args[0]
        name = args[1] if len(args) > 1 else ''
        if verb == 'list':
            result = json.dumps([dict(Name=n, State=g['State']) for n, g in guests.items()])
        elif verb == 'get':
            result = json.dumps(guests[name])
        elif verb == 'clone':
            guests[args[2]] = dict(State='stopped', CPU=4, Memory=8192)
        elif verb == 'set':
            guests[name].update(CPU=int(args[args.index('--cpu')+1]), Memory=int(args[args.index('--memory')+1]))
        elif verb == 'run':
            if state.get('softnet_failures', 0) > 0:
                state['softnet_failures'] -= 1
                result = 'Error: RuntimeFailed'
            else:
                guests[args[-1]]['State'] = 'running'
                state['boots'] += 1
        elif verb == 'stop':
            # The real `tart stop` fails on a guest that is not running.
            code = 2 * int(guests[name]['State'] != 'running')
            guests[name]['State'] = 'stopped'
        elif verb == 'delete':
            del guests[name]
        elif verb == 'rename':
            guests[args[2]] = guests.pop(name)
        elif verb == 'exec':
            code = int(guests[name]['State'] != 'running')
        elif verb == 'ip':
            result = '192.0.2.' + str(state['calls'].count(['tart', 'ip', name]) % 200 + 1)
    elif tool == 'nc':
        code = int(state['boots'] <= state.get('unreachable_boots', 0))
    elif tool == 'sshpass':
        if 'scp' in args:
            code = int(any(pathlib.Path(a).is_dir() for a in args if a.startswith('/')))
        elif 'shutdown' in args[-1]:
            for g in guests.values():
                g['State'] = 'stopped'
        elif args[-1] == 'bash ~/vm/renew-approvals.sh':
            code = state.get('renewal_failure', 0)
            state['approvals_ready'] = code == 0
        elif '~/vm/preflight' in args[-1] and state.get('require_approval_renewal'):
            code = int(not state.get('approvals_ready'))
    f.seek(0); json.dump(state, f); f.truncate()
if tool == 'sysctl' and args[-1] == 'hw.ncpu' and state.get('block_host'):
    with (root / 'ready').open('w') as ready:
        ready.write(str(os.getpid()))
    with (root / 'release').open('r') as release:
        release.read()
if result: print(result)
sys.exit(code)
'''


class VMTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        tools = self.root / 'bin'
        tools.mkdir()
        for tool in ('tart', 'sshpass', 'nc', 'sysctl', 'rsync', 'sleep'):
            path = tools / tool
            path.write_text(f'#!{sys.executable}\n' + SHIM)
            path.chmod(0o755)
        self.env = dict(os.environ, PATH=f'{tools}:{os.environ["PATH"]}',
                        TART_HOME=str(self.root / 'tart'), VM_TEST_STATE=str(self.root))
        for key in ('VM_CPU', 'VM_MEMORY', 'VM_GOLDEN'):
            self.env.pop(key, None)
        self.seed()

    def seed(self, guests=None, **settings):
        state = dict(guests={'winmux-golden': dict(State='stopped', CPU=4, Memory=8192), **(guests or {})},
                     calls=[], boots=0, cores=10, memory=16 * 1024**3)
        state.update(settings)
        (self.root / 'state.json').write_text(json.dumps(state))

    def state(self):
        return json.loads((self.root / 'state.json').read_text())

    def run_vm(self, *args, **overrides):
        return subprocess.run([str(VM), *args], env=dict(self.env, **overrides),
                              capture_output=True, text=True, timeout=120)

    def assert_started(self, result, name, cpu=3, memory=5120):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['tart', 'set', name, '--cpu', str(cpu), '--memory', str(memory), '--display', '1280x720'], self.state()['calls'])
        self.assertEqual(self.state()['guests'][name]['State'], 'running')

    def assert_refused(self, result, *messages):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        for message in messages:
            self.assertIn(message, result.stderr)
        self.assertFalse(any(c[:2] == ['tart', 'clone'] for c in self.state()['calls']))

    def test_third_guest_names_all_running_guests_and_leaves_no_clone(self):
        self.seed({'a': guest(), 'foreign-runner': guest()})
        self.assert_refused(self.run_vm('up', 'c'), 'two-guest limit', 'a', 'foreign-runner', '3 cores', '5120 MB')
        self.assertNotIn('c', self.state()['guests'])

    def test_stopped_guest_boots_without_golden_image(self):
        self.seed({'kept': guest('stopped')})
        state = self.state()
        del state['guests']['winmux-golden']
        (self.root / 'state.json').write_text(json.dumps(state))
        self.assert_started(self.run_vm('up', 'kept'), 'kept')
        self.assertFalse(any(c[:2] == ['tart', 'clone'] for c in self.state()['calls']))

    def test_new_guest_requires_golden_image(self):
        self.seed()
        state = self.state()
        del state['guests']['winmux-golden']
        (self.root / 'state.json').write_text(json.dumps(state))
        self.assert_refused(self.run_vm('up', 'new'), 'missing', 'build-image')

    def test_second_guest_uses_default_size(self):
        self.seed({'a': guest()})
        self.assert_started(self.run_vm('up', 'b'), 'b')

    def test_boot_uses_ssh_without_contacting_the_guest_agent(self):
        self.assert_started(self.run_vm('up', 'a'), 'a')
        calls = self.state()['calls']
        self.assertFalse(any(c[:2] == ['tart', 'exec'] for c in calls))
        self.assertTrue(any(c[0] == 'sshpass' and c[-1] == 'true' for c in calls))

    def test_up_renews_approvals_before_the_preflight(self):
        self.seed(require_approval_renewal=True)
        self.assert_started(self.run_vm('up', 'a'), 'a')

    def test_up_stops_before_preflight_when_renewal_fails(self):
        self.seed(renewal_failure=1)
        result = self.run_vm('up', 'a')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[0] == 'sshpass' and '~/vm/preflight' in c[-1]
                             for c in self.state()['calls']))

    def test_cpu_above_cap_is_refused_even_when_empty(self):
        self.assert_refused(self.run_vm('up', 'a', VM_CPU='8'), 'cap', '7 cores', '11264 MB', '8 cores')

    def test_raised_size_exactly_fits_beside_default(self):
        self.seed({'a': guest()})
        self.assert_started(self.run_vm('up', 'b', VM_CPU='4', VM_MEMORY='6144'), 'b', 4, 6144)

    def test_raised_cpu_does_not_fit(self):
        self.seed({'a': guest()})
        self.assert_refused(self.run_vm('up', 'b', VM_CPU='5'), 'cap', 'a', '5 cores')

    def test_raised_memory_does_not_fit(self):
        self.seed({'a': guest()})
        self.assert_refused(self.run_vm('up', 'b', VM_MEMORY='6145'), 'cap', 'a', '6145 MB')

    def test_cap_is_computed_and_memory_rounded_down_to_gb(self):
        state = self.state()
        state.update(cores=8, memory=10 * 1024**3 + 512 * 1024**2)
        (self.root / 'state.json').write_text(json.dumps(state))
        self.assert_refused(self.run_vm('up', 'a', VM_CPU='6'), '5 cores', '7168 MB')

    def test_stopped_guests_are_not_counted(self):
        self.seed({'a': guest(), 'stopped': guest('stopped', 100, 100000)})
        self.assert_started(self.run_vm('up', 'b'), 'b')
        self.assertNotIn(['tart', 'get', 'stopped', '--format', 'json'], self.state()['calls'])

    def test_build_image_refuses_third_guest(self):
        self.seed({'a': guest(), 'b': guest()})
        self.assert_refused(self.run_vm('build-image', VM_GOLDEN='new-golden'), 'two-guest limit', 'a', 'b')

    def test_build_image_uses_size_overrides_and_default(self):
        for overrides, cpu, memory in (({}, 3, 5120), ({'VM_CPU': '4', 'VM_MEMORY': '6144'}, 4, 6144)):
            with self.subTest(overrides=overrides):
                self.seed()
                result = self.run_vm('build-image', VM_GOLDEN='new-golden', **overrides)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(['tart', 'set', 'new-golden-build', '--cpu', str(cpu), '--memory', str(memory), '--display', '1280x720'], self.state()['calls'])

    def test_image_transport_ignores_generated_directories_beside_recipe_files(self):
        import shutil
        recipe = self.root / 'recipe'
        recipe.mkdir()
        for name in ('vm', 'start_locked.py'):
            shutil.copy2(VM.parent / name, recipe / name)
        sources = recipe / 'guest'
        sources.mkdir()
        (sources / 'provision.sh').write_text('echo provisioned\n')
        (sources / '__pycache__').mkdir()
        result = subprocess.run([str(recipe / 'vm'), 'build-image'],
                                env=dict(self.env, VM_GOLDEN='replacement'),
                                capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stderr)
        copies = [c for c in self.state()['calls'] if c[0] == 'sshpass' and 'scp' in c]
        self.assertTrue(any(str(sources / 'provision.sh') in c for c in copies))

    def test_unreachable_guest_is_stopped_then_second_boot_succeeds(self):
        self.seed(unreachable_boots=1)
        result = self.run_vm('up', 'a')
        self.assert_started(result, 'a')
        self.assertIn('rebooting unreachable guest', result.stderr)
        self.assertEqual(self.state()['boots'], 2)
        calls = self.state()['calls']
        self.assertIn(['tart', 'stop', 'a'], calls)
        probes = [c for c in calls if c[0] == 'nc']
        self.assertGreater(len(probes), 1)
        self.assertGreater(len({c[-2] for c in probes}), 1, 're-read the IP on every probe')
        self.assertLessEqual(len(probes), 21, 'about one minute per failed attempt')

    def test_unreachable_guest_exhausts_three_tries_and_is_stopped(self):
        self.seed(unreachable_boots=3)
        result = self.run_vm('up', 'a')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.state()['boots'], 3)
        self.assertEqual(self.state()['guests']['a']['State'], 'stopped')

    def test_softnet_failure_is_retried(self):
        self.seed(softnet_failures=1)
        self.assert_started(self.run_vm('up', 'a'), 'a')
        self.assertEqual(sum(c[:2] == ['tart', 'run'] for c in self.state()['calls']), 2)

    def test_stop_shuts_the_guest_down_and_keeps_it(self):
        self.seed({'a': guest()})
        result = self.run_vm('stop', 'a')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state()['guests']['a']['State'], 'stopped')
        self.assertTrue(any(c[0] == 'sshpass' and 'shutdown' in c[-1] for c in self.state()['calls']))
        self.assertEqual(self.run_vm('stop', 'a').returncode, 0)

    def test_every_verb_refuses_without_tart_home(self):
        env = dict(self.env)
        del env['TART_HOME']
        result = subprocess.run([str(VM), 'ssh', 'a', 'true'], env=env, capture_output=True, text=True, timeout=120)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('TART_HOME is unset', result.stderr)

    def test_invalid_overrides_fail_before_mutation(self):
        for overrides in ({'VM_CPU': '0'}, {'VM_CPU': '3.5'}, {'VM_MEMORY': '-1'}, {'VM_MEMORY': 'five'}):
            with self.subTest(overrides=overrides):
                self.seed()
                self.assert_refused(self.run_vm('up', 'a', **overrides), 'positive integer')

    def test_two_simultaneous_starts_only_admit_one_beside_running_guest(self):
        self.seed({'a': guest()})
        processes = [subprocess.Popen([str(VM), 'up', n], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for n in ('b', 'c')]
        results = [(p.communicate(timeout=120), p.returncode) for p in processes]
        self.assertEqual(sorted(code for _, code in results), [0, 1], results)
        state = self.state()
        self.assertEqual(sum(g['State'] == 'running' for g in state['guests'].values()), 2)
        self.assertEqual(sum(c[:2] == ['tart', 'clone'] for c in state['calls']), 1)
        self.assertIn('waiting for another guest', ''.join(err for (_, err), _ in results))

    def test_killed_admission_releases_lock_even_while_tool_is_alive(self):
        self.seed(block_host=True)
        for name in ('ready', 'release'):
            os.mkfifo(self.root / name)
        ready_fd = os.open(self.root / 'ready', os.O_RDWR | os.O_NONBLOCK)
        self.addCleanup(os.close, ready_fd)
        first = subprocess.Popen([str(VM), 'up', 'b'], env=self.env,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: first.poll() is None and first.kill())
        self.assertTrue(select.select([ready_fd], [], [], 10)[0], 'admission never reached sysctl')
        child = int(os.read(ready_fd, 64))
        self.addCleanup(lambda: os.kill(child, signal.SIGKILL))
        first.kill()
        first.wait(timeout=5)
        state = self.state()
        state['block_host'] = False
        (self.root / 'state.json').write_text(json.dumps(state))
        self.assert_started(self.run_vm('up', 'c'), 'c')

    def test_build_image_obeys_resource_cap_before_clone(self):
        self.assert_refused(self.run_vm('build-image', VM_GOLDEN='new-golden', VM_MEMORY='11265'), 'cap', '11264 MB')

    def test_unreadable_running_guest_size_fails_closed(self):
        self.seed({'foreign': dict(State='running', CPU=3)})
        self.assert_refused(self.run_vm('up', 'b'), 'cannot read memory of foreign')


def guest(state='running', cpu=3, memory=5120):
    return dict(State=state, CPU=cpu, Memory=memory)


class AutomationRecipeTest(unittest.TestCase):
    def test_grants_only_observed_calendar_requester_and_five_automation_targets(self):
        import sqlite3
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            user = root / 'Library/Application Support/com.apple.TCC/TCC.db'
            user.parent.mkdir(parents=True)
            system = root / 'system.db'
            schema = """create table access (service text, client text, client_type integer,
                auth_value integer, auth_reason integer, csreq blob,
                indirect_object_identifier text, indirect_object_identifier_type integer,
                primary key(service,client,indirect_object_identifier))"""
            for path in [user, system]:
                with contextlib.closing(sqlite3.connect(path)) as db, db:
                    db.execute(schema)
            client = '/usr/libexec/sshd-keygen-wrapper'
            with contextlib.closing(sqlite3.connect(system)) as db, db:
                db.execute('insert into access values (?,?,?,?,?,?,?,?)',
                           ('kTCCServiceSystemPolicyAllFiles', client, 1, 2, 4, b'identity', 'UNUSED', 0))
            binary = root / 'bin'
            binary.mkdir()
            shims = {
                'sudo': '#!/bin/sh\nexec "$@"\n',
                'killall': '#!/bin/sh\nexit 0\n',
                'chown': '#!/bin/sh\nexit 0\n',
                'sqlite3': '#!' + sys.executable + '\n' + r'''import contextlib, os, sqlite3, sys
from pathlib import Path
root = Path(os.environ['HOME'])
path, query = sys.argv[1:]
query = query.replace('/Library/Application Support/com.apple.TCC/TCC.db', str(root / 'system.db'))
with contextlib.closing(sqlite3.connect(path)) as db, db:
    for statement in query.split(';'):
        if statement.strip():
            cursor = db.execute(statement)
            for row in cursor.fetchall():
                print('|'.join('' if v is None else str(v) for v in row))
'''
            }
            for name, body in shims.items():
                (binary / name).write_text(body)
                (binary / name).chmod(0o755)
            subprocess.run(['bash', str(VM.parent / 'guest/automation.sh')], check=True,
                           env=dict(os.environ, HOME=str(root), USER='test', PATH=str(binary) + ':' + os.environ['PATH']))
            with contextlib.closing(sqlite3.connect(user)) as db, db:
                rows = db.execute('select service,client,client_type,auth_value,auth_reason,csreq,indirect_object_identifier from access').fetchall()
            self.assertEqual(len(rows), 6)
            self.assertEqual({r[6] for r in rows if r[0] == 'kTCCServiceAppleEvents'},
                             {'com.apple.Notes', 'com.apple.finder', 'com.apple.systemevents', 'com.apple.iCal', 'com.apple.Music'})
            self.assertEqual([r[6] for r in rows if r[0] == 'kTCCServiceCalendar'], ['UNUSED'])
            for row in rows:
                self.assertEqual(row[1:6], (client, 1, 2, 4, b'identity'))
            with contextlib.closing(sqlite3.connect(system)) as db, db:
                self.assertEqual(db.execute('select count(*) from access').fetchone()[0], 1)


class FirstRunRecipeTest(unittest.TestCase):
    def test_initializes_local_props_and_preserves_notes_onboarding_settings(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            binary = root / 'bin'
            binary.mkdir()
            vm = root / 'vm'
            vm.mkdir()
            (vm / 'quiet-desktop.py').write_text('')
            (vm / 'dock-tile-registered').touch()
            for tool in ['sleep', 'killall', 'pkill']:
                (binary / tool).write_text('#!/bin/sh\nexit 0\n')
                (binary / tool).chmod(0o755)
            shim = '#!' + sys.executable + '\n' + '''import json, os, pathlib, sys
root = pathlib.Path(os.environ['HOME'])
p = root / 'prefs.json'
s = json.loads(p.read_text()) if p.exists() else {'opened': [], 'quit': [], 'prefs': {}}
tool = pathlib.Path(sys.argv[0]).name
a = sys.argv[1:]
if tool == 'open': s['opened'].append(a[-1])
elif tool == 'osascript': s['quit'].append(a[-1].split('"')[1])
elif tool == 'defaults': s['prefs'][a[1] + ':' + a[2]] = a[3:]
p.write_text(json.dumps(s))
'''
            for tool in ['open', 'osascript', 'defaults']:
                (binary / tool).write_text(shim)
                (binary / tool).chmod(0o755)
            subprocess.run(['bash', str(VM.parent / 'guest/first-run.sh')], check=True,
                           env=dict(os.environ, HOME=str(root), PATH=str(binary) + ':' + os.environ['PATH']))
            state = json.loads((root / 'prefs.json').read_text())
            self.assertEqual(state['opened'], ['Notes', 'Calendar', 'Music'])
            self.assertEqual(state['quit'], ['Notes', 'Calendar', 'Music'])
            prefs = state['prefs']
            notes = str(root / 'Library/Containers/com.apple.Notes/Data/Library/Preferences/com.apple.Notes')
            self.assertEqual(prefs[notes + ':hasShownWelcomeScreen'], ['-bool', 'true'])
            self.assertEqual(prefs[notes + ':bypassICloudAlert'], ['-bool', 'true'])
            self.assertIn(notes + ':lastShownStartupVersion-1', prefs)
            self.assertEqual(prefs['com.apple.iCal:number of hours displayed'], ['-int', '24'])
            self.assertEqual(prefs['com.apple.Music:showWelcomeScreenState'], ['-int', '2'])
            self.assertEqual(prefs['com.apple.Music:showAppleMusic'], ['-bool', 'false'])
