#!/usr/bin/env python3
"""Run Finix tests and write a CI summary"""

import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
DISCOVER = r'''
let
  walk = path: value:
    if builtins.isAttrs value then
      if value ? drvPath then
        [{ name = builtins.concatStringsSep "." path; drvPath = value.drvPath; }]
      else builtins.concatLists (map
        (name: walk (path ++ [name]) (builtins.getAttr name value))
        (builtins.attrNames value))
    else [];
in walk [] (import ./tests {})
'''


def command(argv, folder, label, timeout):
    started = time.monotonic()
    with (folder / (label + '.stdout.log')).open('wb') as out, (
        folder / (label + '.stderr.log')
    ).open('wb') as err:
        try:
            rc = subprocess.run(
                argv, cwd=ROOT, stdout=out, stderr=err, timeout=timeout,
                env={**os.environ, 'TERM': 'dumb', 'NO_COLOR': '1'},
                check=False,
            ).returncode
        except subprocess.TimeoutExpired:
            err.write(f'\nReporter: command timed out after {timeout}s\n'.encode())
            rc = 124
        except OSError as exc:
            err.write(f'\nReporter: {exc}\n'.encode())
            rc = 127
    return rc, round(time.monotonic() - started, 3)


def read_small(path, limit=4 * 1024 * 1024):
    with path.open('rb') as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError(f'{path.name} exceeds the metadata size limit')
    return data.decode('utf-8', errors='replace')


def lines(path):
    with path.open(encoding='utf-8', errors='replace') as stream:
        for line in stream:
            yield ANSI.sub('', line).strip()


def excerpt(path, limit=5000):
    if not path.exists():
        return ''
    with path.open('rb') as stream:
        stream.seek(0, 2)
        stream.seek(max(0, stream.tell() - limit))
        return ANSI.sub('', stream.read().decode('utf-8', errors='replace'))


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(65536), b''):
            value.update(chunk)
    return value.digest()


def outputs(drv, folder, label):
    rc, _ = command(['nix-store', '--query', '--outputs', drv], folder, label, 300)
    if rc:
        return None
    paths = read_small(folder / (label + '.stdout.log')).splitlines()
    if not paths or any(not p.startswith('/nix/store/') for p in paths):
        return None
    return {p: Path(p).exists() for p in paths}


def parse_driver_log(path):
    stack, records = [], []
    driver_seen = False
    driver_error = False
    consistent = True
    for line in lines(path):
        if line in ('run the VM test script', 'start all VLans', 'start all VMs'):
            driver_seen = True
        if line.startswith('!!! ') or line == 'timeout reached - test terminating...':
            driver_error = True
        start = re.fullmatch(r'subtest: (.+)', line)
        finish = re.fullmatch(r'\(finished: subtest: (.+), in ([0-9]+(?:\.[0-9]+)?) seconds\)', line)
        failed = re.fullmatch(r'(?:!!! )?Test "(.+)" failed with error: .*', line)
        if start:
            record = {'name': start[1], 'status': 'unknown'}
            records.append(record)
            stack.append(record)
        elif finish is not None or failed is not None:
            match = finish if finish is not None else failed
            if match is None or not stack or stack[-1]['name'] != match[1]:
                consistent = False
                continue
            record = stack.pop()
            record['status'] = 'passed' if finish else 'failed'
            if finish:
                record['seconds'] = float(finish[2])
            else:
                driver_error = True
    return (records if driver_seen and consistent else []), driver_seen, driver_error


def run_test(test, index, artifact_dir, timeout):
    folder = artifact_dir / f'{index:03d}'
    folder.mkdir()
    drv = test['drvPath']
    result = {**test, 'logs': str(folder.relative_to(artifact_dir)), 'warnings': []}
    before = outputs(drv, folder, 'outputs-before')
    result['outputs_before'] = before
    cached = before is not None and all(before.values())
    previous_log_rc, _ = command(['nix-store', '--read-log', drv], folder, 'derivation-before', 300)
    rc, seconds = command(
        ['nix-build', drv, '--no-out-link', '--show-trace'], folder, 'build', timeout,
    )
    result.update(exit_code=rc, seconds=seconds, status='passed' if rc == 0 else 'failed')
    after = outputs(drv, folder, 'outputs-after')
    result['outputs_after'] = after
    if rc == 0 and (after is None or not all(after.values())):
        result['status'] = 'failed'
        result['warnings'].append('Build returned success but output availability could not be verified.')

    started = False
    build_evidence = None
    for line in lines(folder / 'build.stderr.log'):
        if re.match(r"^building ['‘]" + re.escape(drv) + r"['’](?: on .+)?\.\.\.$", line):
            started = True
        if (re.search(r'dependenc(?:y|ies) of derivation .* failed to build', line)
                or 'a required system feature' in line
                or re.search(r'requires .* with features', line)):
            build_evidence = line
    result['execution'] = (
        'cached (available before build)' if cached else
        'target build observed' if started else
        'substituted or execution unverified'
    )
    log_rc, _ = command(['nix-store', '--read-log', drv], folder, 'derivation', 300)
    log_changed = log_rc == 0 and (
        previous_log_rc != 0 or
        digest(folder / 'derivation.stdout.log') != digest(folder / 'derivation-before.stdout.log')
    )
    current_log = started and not cached and log_changed
    result['driver_log_provenance'] = 'current target build' if current_log else 'historical/unverified'
    subtests, driver_seen, driver_error = ([], False, False)
    if log_rc == 0:
        subtests, driver_seen, driver_error = parse_driver_log(folder / 'derivation.stdout.log')
    else:
        result['warnings'].append('Target derivation log unavailable - inspect build.stderr.log.')
    result['subtests'] = subtests
    result['failure_stage'] = None
    if result['status'] == 'failed':
        if current_log and driver_seen and driver_error:
            result['failure_stage'] = 'VM/test driver'
            result['failure_evidence'] = 'Current target log contains driver activity and explicit driver error/timeout.'
        elif build_evidence:
            result['failure_stage'] = 'build/dependency'
            result['failure_evidence'] = build_evidence
        else:
            result['failure_stage'] = 'undetermined'
            result['failure_evidence'] = 'No reliable evidence separating build failure from VM execution failure.'

    for number, (output, exists) in enumerate((after or {}).items()):
        if not exists or not Path(output).is_dir():
            continue
        for source in Path(output).iterdir():
            if source.is_file() and source.suffix in ('.log', '.xml', '.txt', '.json'):
                dest = folder / f'output-{number}'
                dest.mkdir(exist_ok=True)
                try:
                    shutil.copyfile(source, dest / source.name)
                except OSError as exc:
                    result['warnings'].append(f'Could not copy {source.name}: {exc}')
    return result


def cell(value, limit=600):
    text = str(value)
    if len(text) > limit:
        text = text[:limit] + '…'
    return html.escape(text).replace('|', '&#124;').replace('\n', ' ').replace('\r', ' ').replace('`', '&#96;')


def summary(results, errors, artifact_dir):
    failed = sum(r['status'] == 'failed' for r in results)
    skipped = sum(r['status'] == 'skipped' for r in results)
    rows = [
        '## Finix VM test results', '',
        (f'**{len(results) - failed - skipped} passed · {failed} failed · '
         f'{skipped} skipped · {len(errors)} errors**'), '',
        '| Test | Result | Time | Subtests | Logs |',
        '| --- | --- | ---: | --- | --- |',
    ]
    for result in results:
        counts = {s: sum(t['status'] == s for t in result.get('subtests', [])) for s in ('passed', 'failed', 'unknown')}
        sub = ', '.join(f'{n} {s}' for s, n in counts.items() if n) or 'unavailable'
        if result.get('subtests'):
            sub += ' (' + result['driver_log_provenance'] + ')'
        status = result['status']
        if result.get('failure_stage'):
            status += ': ' + result['failure_stage']
        rows.append('| ' + ' | '.join(cell(v) for v in (
            result['name'], status, f"{result.get('seconds') or 0:.1f}s", sub,
            result.get('logs') or 'n/a',
        )) + ' |')
    rows += ['', f'Logs: **{cell(artifact_dir)}**', '']
    for error in errors:
        rows += ['### Runner error', '', '<pre>' + html.escape(error[:6000]) + '</pre>', '']
    for result in results:
        paths = result.get('outputs_after') or result.get('outputs_before') or {}
        rows += [f"<details><summary>{cell(result['name'])}</summary>", '',
                 f"Derivation: <code>{cell(result['drvPath'])}</code>", '',
                 f"Build exit code: {result.get('exit_code', 'unavailable')}", '']
        for path, exists in paths.items():
            rows.append(f'- <code>{cell(path)}</code> - {"available" if exists else "missing"}')
        if not paths:
            rows.append('Output paths unavailable - see output-query logs.')
        for warning in result.get('warnings', []):
            rows += ['', cell(warning)]
        if result.get('subtests'):
            rows += ['', f"Subtest records ({cell(result['driver_log_provenance'])}):", '']
            for subtest in result['subtests'][:50]:
                rows.append(f"- {cell(subtest['name'])}: {subtest['status']}")
            if len(result['subtests']) > 50:
                rows.append('- Further records are in results.json.')
        if result['status'] == 'failed':
            rows += ['', cell(result.get('failure_evidence', 'Reporter error - see results.json.')), '']
            for filename in ('build.stderr.log', 'derivation.stdout.log'):
                tail = excerpt(artifact_dir / result['logs'] / filename)
                if tail:
                    label = filename
                    if filename.startswith('derivation'):
                        label += ' (' + result.get('driver_log_provenance', 'unverified') + ')'
                    rows += [f'**{cell(label)} - final excerpt**', '', '<pre>' + html.escape(tail) + '</pre>', '']
        rows += ['', '</details>', '']
    return '\n'.join(rows)


def main():
    artifact_dir = Path(os.environ.get('TEST_SUMMARY_ARTIFACT_DIR', 'test-results'))
    if not artifact_dir.is_absolute():
        artifact_dir = ROOT / artifact_dir
    artifact_dir = artifact_dir / (time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()) + f'-{os.getpid()}')
    artifact_dir.mkdir(parents=True, exist_ok=False)
    results, errors = [], []
    interrupted = False
    try:
        timeout = int(os.environ.get('TEST_SUMMARY_BUILD_TIMEOUT', '7200'))
        if timeout <= 0:
            raise ValueError('TEST_SUMMARY_BUILD_TIMEOUT must be a positive integer')
        rc, _ = command(
            ['nix-instantiate', '--eval', '--strict', '--json', '--read-write-mode', '--expr', DISCOVER],
            artifact_dir, 'discovery', 1800,
        )
        if rc:
            raise RuntimeError('Test discovery failed:\n' + excerpt(artifact_dir / 'discovery.stderr.log'))
        tests = json.loads(read_small(artifact_dir / 'discovery.stdout.log'))
        if not isinstance(tests, list) or not tests:
            raise ValueError('Discovery returned no test derivations')
        for test in tests:
            if (not isinstance(test, dict) or not isinstance(test.get('name'), str)
                    or not isinstance(test.get('drvPath'), str)
                    or not test['drvPath'].startswith('/nix/store/')
                    or not test['drvPath'].endswith('.drv')):
                raise ValueError('Discovery returned an invalid test derivation')
        fail_fast = os.environ.get('TEST_SUMMARY_FAIL_FAST', '1').strip().lower() not in (
            '0', 'false', 'no', 'off', '',
        )
        stopped_at = None
        for index, test in enumerate(tests, 1):
            if stopped_at is not None:
                results.append({
                    **test, 'logs': f'{index:03d} (not run)', 'status': 'skipped',
                    'seconds': 0, 'exit_code': None, 'subtests': [],
                    'outputs_before': None, 'outputs_after': None,
                    'warnings': [f'Skipped: run stopped after {stopped_at}.'],
                    'failure_stage': None, 'execution': 'not run',
                    'driver_log_provenance': 'not run',
                })
                print(f"[{index}/{len(tests)}] {test['name']} - skipped", flush=True)
                continue
            print(f"[{index}/{len(tests)}] {test['name']}", flush=True)
            aborted = False
            try:
                result = run_test(test, index, artifact_dir, timeout)
            except (OSError, ValueError) as exc:
                result = {**test, 'status': 'failed', 'logs': f'{index:03d}',
                          'warnings': [f'Reporter error: {exc}'], 'failure_stage': 'reporter'}
            except Exception as exc:  # noqa: BLE001 - reporter must never lose the remaining tests
                result = {**test, 'status': 'failed', 'logs': f'{index:03d}',
                          'warnings': [f'Reporter error: {exc!r}'], 'failure_stage': 'reporter'}
                errors.append(f'Aborted at {test["name"]}: {exc!r}')
                aborted = True
            results.append(result)
            (artifact_dir / 'results.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
            if aborted or (fail_fast and result['status'] == 'failed'):
                stopped_at = test['name']
    except KeyboardInterrupt:
        interrupted = True
        errors.append('Interrupted: remaining tests did not complete. Logs for the interrupted command may be partial.')
    except (OSError, ValueError, RuntimeError) as exc:
        errors.append(str(exc))
    report = summary(results, errors, artifact_dir)
    (artifact_dir / 'summary.md').write_text(report, encoding='utf-8')
    (artifact_dir / 'results.json').write_text(
        json.dumps({'tests': results, 'runner_errors': errors}, indent=2) + '\n', encoding='utf-8',
    )
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        try:
            inline = report
            if len(inline.encode('utf-8')) > 900_000:
                inline = '\n'.join(report.splitlines()[:7]) + '\n\nReport exceeds inline size limit - see summary.md in the artifact.\n'
            with open(summary_path, 'a', encoding='utf-8') as stream:
                stream.write('\n' + inline + '\n')
        except OSError as exc:
            print(f'Cannot append GITHUB_STEP_SUMMARY: {exc}', file=sys.stderr)
            return 1
    print(f'Summary and logs: {artifact_dir}', flush=True)
    if interrupted:
        return 130
    if errors:
        return 2
    if any(r['status'] == 'failed' for r in results):
        return 1
    if any(r['status'] == 'skipped' for r in results):
        return 3
    return 0


if __name__ == '__main__':
    sys.exit(main())
