#!/usr/bin/env python3
"""Validate the proposed MUSH dialogue without importing or running the game."""
import copy
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHANNELS = {'meeting', 'greeting', 'quest', 'relationship', 'festival', 'idle', 'main'}
ID = re.compile(r'^[a-z][a-z0-9_]*$')


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'duplicate JSON key: {key}')
        result[key] = value
    return result


def read(path):
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique_object)


def declarations(manifest):
    flags, events, items, locations = set(), set(manifest['world_events']), set(), {'home'}
    for char in manifest['characters']:
        cid, quest = char['id'], char['quest']
        flags.update(f'{p}_{cid}' for p in ('met', 'friend', 'trusted'))
        flags.update(f"{quest['id']}_{p}" for p in ('accepted', 'prepared', 'done'))
        events.add(quest['event'])
        items.add(quest['reward'])
        locations.add(char['location'])
    for quest in manifest['main_quests']:
        flags.update(f"{quest['id']}_{p}" for p in ('accepted', 'done'))
    return flags | events, events, items, locations


def validate(data, manifest):
    errors, global_ids = [], set()
    flags, events, items, locations = declarations(manifest)
    roster = {c['id']: c for c in manifest['characters']}
    def require(ok, message):
        if not ok:
            errors.append(message)
    require(set(data) == set(roster), 'character file set does not match manifest')
    def condition(value, context):
        if not isinstance(value, dict) or len(value) != 1:
            require(False, f'{context}: condition must contain one key'); return
        key, arg = next(iter(value.items()))
        if key in ('flag', 'not_flag'):
            ok = isinstance(arg, str) and arg in flags
        elif key == 'visited':
            ok = isinstance(arg, str) and arg in locations
        elif key == 'time':
            ok = arg in ('dawn', 'day', 'dusk', 'night')
        elif key == 'weather':
            ok = arg in ('clear', 'rain')
        elif key in ('garden_planted_gte', 'furniture_placed_gte', 'magic_gte', 'magic_lt'):
            maximum = {'garden_planted_gte': 8, 'furniture_placed_gte': 6}.get(key, 100)
            ok = type(arg) is int and 0 <= arg <= maximum
        else:
            ok = False
        require(ok, f'{context}: invalid condition {value}')
    def conditions(values, context):
        require(isinstance(values, list), f'{context}: conditions must be a list')
        if isinstance(values, list):
            for value in values:
                condition(value, context)
    for cid, doc in data.items():
        if cid not in roster:
            continue
        require(set(doc) == {'schema_version', 'character', 'quests', 'entries', 'nodes'}, f'{cid}: top-level fields')
        require(doc.get('schema_version') == 1 and doc.get('character') == cid, f'{cid}: identity/version')
        personal = roster[cid]['quest']
        owned_flags = {f'{p}_{cid}' for p in ('met', 'friend', 'trusted')} | {f"{personal['id']}_{p}" for p in ('accepted', 'prepared', 'done')}
        owned_flags |= {f"{q['id']}_{p}" for q in manifest['main_quests'] if q['owner'] == cid for p in ('accepted', 'done')}
        expected = {roster[cid]['quest']['id']} | {q['id'] for q in manifest['main_quests'] if q['owner'] == cid}
        require(isinstance(doc.get('quests'), list) and set(doc['quests']) == expected and len(doc['quests']) == len(expected), f'{cid}: quest coverage')
        nodes, entries = doc.get('nodes', []), doc.get('entries', {})
        require(isinstance(nodes, list) and bool(nodes), f'{cid}: nodes must be a nonempty list')
        require(isinstance(entries, dict), f'{cid}: entries must be an object')
        if not isinstance(nodes, list) or not isinstance(entries, dict):
            continue
        index = {}
        for node in nodes:
            if not isinstance(node, dict):
                require(False, f'{cid}: node must be object'); continue
            nid = node.get('id', '')
            require(isinstance(nid, str) and bool(ID.fullmatch(nid)) and nid.startswith(cid + '_'), f'{cid}: invalid node id {nid}')
            require(nid not in global_ids, f'{cid}: duplicate node {nid}')
            global_ids.add(nid); index[nid] = node
            require({'id', 'speaker', 'kind', 'text'} <= set(node) <= {'id', 'speaker', 'kind', 'text', 'conditions', 'effects', 'next', 'choices'}, f'{nid}: node fields')
            require(node.get('speaker') == cid and node.get('kind') in CHANNELS, f'{nid}: speaker/kind')
            line = node.get('text')
            require(isinstance(line, str) and bool(line.strip()) and len(line) <= 180 and '—' not in line, f'{nid}: line length/content')
            conditions(node.get('conditions', []), nid)
            effects = node.get('effects', [])
            require(isinstance(effects, list), f'{nid}: effects must be list')
            for effect in effects if isinstance(effects, list) else []:
                ok = isinstance(effect, dict)
                if ok and set(effect) == {'set_flag', 'value'}:
                    ok = effect['set_flag'] in owned_flags and effect['value'] is True
                elif ok and set(effect) == {'give_item'}:
                    ok = effect['give_item'] == personal['reward']
                else:
                    ok = False
                require(ok, f'{nid}: forbidden/invalid effect {effect}')
            writes = {e.get('set_flag') for e in effects if isinstance(e, dict)}
            grants = [e for e in effects if isinstance(e, dict) and 'give_item' in e]
            if grants or personal['id'] + '_done' in writes:
                needed = {personal['id'] + '_accepted', personal['id'] + '_prepared', personal['event']}
                actual = {c.get('flag') for c in node.get('conditions', []) if isinstance(c, dict)}
                require(needed <= actual and personal['id'] + '_done' in writes and bool(grants), f'{nid}: reward/completion lacks own objective gates or atomic grant')
            require(not ('next' in node and 'choices' in node), f'{nid}: both next and choices')
            if 'choices' in node:
                require(isinstance(node['choices'], list) and bool(node['choices']), f'{nid}: empty/invalid choices')
                for choice in node['choices'] if isinstance(node['choices'], list) else []:
                    require(isinstance(choice, dict) and {'text', 'next'} <= set(choice) <= {'text', 'next', 'conditions'}, f'{nid}: choice fields')
                    if not isinstance(choice, dict):
                        continue
                    label = choice.get('text')
                    require(isinstance(label, str) and 0 < len(label.strip()) <= 65 and '—' not in label, f'{nid}: choice text')
                    conditions(choice.get('conditions', []), nid)
        wanted_channels = CHANNELS if len(expected) > 1 else CHANNELS - {'main'}
        require(wanted_channels <= set(entries) <= CHANNELS, f'{cid}: channel coverage')
        roots, links = [], {}
        for channel, ids in entries.items():
            require(isinstance(ids, list) and bool(ids), f'{cid}/{channel}: empty entries')
            if isinstance(ids, list):
                roots.extend(ids)
                for nid in ids:
                    require(nid in index and index[nid].get('kind') == channel, f'{cid}/{channel}: bad entry {nid}')
        for nid, node in index.items():
            targets = ([node['next']] if 'next' in node else []) + [c.get('next') for c in node.get('choices', []) if isinstance(c, dict)]
            links[nid] = targets
            for target in targets:
                require(isinstance(target, str) and target in index, f'{nid}: unresolved next {target}')
        reached, todo = set(), list(roots)
        while todo:
            nid = todo.pop()
            if isinstance(nid, str) and nid in index and nid not in reached:
                reached.add(nid); todo.extend(links.get(nid, []))
        require(reached == set(index), f'{cid}: unreachable nodes {sorted(set(index) - reached)}')
        greeting_pairs = set()
        for nid in entries.get('greeting', []):
            conds = index.get(nid, {}).get('conditions', [])
            merged = {k: v for obj in conds if isinstance(obj, dict) for k, v in obj.items()}
            greeting_pairs.add((merged.get('time'), merged.get('weather')))
        require({(t, w) for t in ('dawn', 'day', 'dusk', 'night') for w in ('clear', 'rain')} <= greeting_pairs, f'{cid}: incomplete time/weather greetings')
    return errors


def eligible(node, state):
    for cond in node.get('conditions', []):
        key, value = next(iter(cond.items()))
        if key == 'flag': ok = value in state['flags']
        elif key == 'not_flag': ok = value not in state['flags']
        elif key == 'visited': ok = value in state['visited']
        elif key in ('time', 'weather'): ok = state[key] == value
        elif key == 'magic_lt': ok = state['magic'] < value
        else: ok = state[{'garden_planted_gte': 'garden', 'furniture_placed_gte': 'furniture', 'magic_gte': 'magic'}[key]] >= value
        if not ok: return False
    return True


def exchange(doc, channel, state, choose=0):
    index = {n['id']: n for n in doc['nodes']}
    current = next((nid for nid in doc['entries'].get(channel, []) if eligible(index[nid], state)), None)
    seen = set()
    while current:
        if current in seen:
            raise ValueError(f'{current}: cycle in representative exchange')
        seen.add(current)
        node = index[current]
        if not eligible(node, state):
            raise ValueError(f'{current}: blocked target in representative exchange')
        for effect in node.get('effects', []):
            state['flags'].add(effect['set_flag']) if 'set_flag' in effect else state['items'].add(effect['give_item'])
        choices = [c for c in node.get('choices', []) if eligible(c, state)]
        current = choices[min(choose, len(choices) - 1)]['next'] if choices else node.get('next')
    return seen


def simulate(data, manifest):
    flags, events, items, locations = declarations(manifest)
    checks = 0
    # Exercise progression under every authored sky pair, at zero magic.
    for time in ('dawn', 'day', 'dusk', 'night'):
        for weather in ('clear', 'rain'):
            state = dict(flags=set(), items=set(), visited=set(), garden=0, furniture=0, magic=0, time=time, weather=weather)
            for char in manifest['characters']:
                cid, q = char['id'], char['quest']
                exchange(data[cid], 'meeting', state)
                assert 'met_' + cid in state['flags'], cid + ': meeting fails'
                assert exchange(data[cid], 'greeting', state), cid + ': no greeting'
                exchange(data[cid], 'quest', state, choose=1)
                assert q['id'] + '_accepted' not in state['flags'], cid + ': defer accepts quest'
                exchange(data[cid], 'quest', state)
                assert q['id'] + '_accepted' in state['flags'], cid + ': acceptance fails'
                exchange(data[cid], 'quest', state)
                assert q['id'] + '_done' not in state['flags'], cid + ': premature completion'
                state['visited'].add(char['location'])
                exchange(data[cid], 'quest', state)
                assert q['id'] + '_prepared' in state['flags'], cid + ': preparation fails'
                exchange(data[cid], 'quest', state)
                assert q['id'] + '_done' not in state['flags'], cid + ': missing world-event gate'
                state['flags'].add(q['event'])
                exchange(data[cid], 'quest', state)
                assert q['id'] + '_done' in state['flags'] and q['reward'] in state['items'], cid + ': completion/reward fails'
                exchange(data[cid], 'relationship', state)
                assert 'friend_' + cid in state['flags'], cid + ': friendship fails'
                checks += 1
            # Main story can also be walked without side quests in the second pass below.
            for quest in manifest['main_quests']:
                doc = data[quest['owner']]
                exchange(doc, 'main', state)
                assert quest['id'] + '_accepted' in state['flags'], quest['id'] + ': accept fails'
                state.update(garden=3, furniture=1)
                state['visited'].update(locations)
                state['flags'].update(events & {c['flag'] for c in quest['conditions'] if 'flag' in c})
                exchange(doc, 'main', state)
                assert quest['id'] + '_done' in state['flags'], quest['id'] + ': main completion fails'
                checks += 1
            for cid in data:
                exchange(data[cid], 'relationship', state)
                assert 'trusted_' + cid in state['flags'], cid + ': trusted stage fails'
                assert exchange(data[cid], 'festival', state), cid + ': no festival aftermath'
                checks += 1
    state = dict(flags={'met_' + c for c in data}, items=set(), visited=set(locations), garden=3, furniture=1, magic=0, time='day', weather='rain')
    for quest in manifest['main_quests']:
        exchange(data[quest['owner']], 'main', state, choose=1)
        assert quest['id'] + '_accepted' not in state['flags'], quest['id'] + ': defer accepts main quest'
        exchange(data[quest['owner']], 'main', state)
        state['flags'].update(events & {c['flag'] for c in quest['conditions'] if 'flag' in c})
        exchange(data[quest['owner']], 'main', state)
        assert quest['id'] + '_done' in state['flags'], quest['id'] + ': depends on side quest'
        checks += 1
    # Isolate each side quest: it may not depend on another resident or the finale.
    for char in manifest['characters']:
        cid, q = char['id'], char['quest']
        for after in (False, True):
            state = dict(flags={'m_festival_done'} if after else set(), items=set(), visited={char['location']}, garden=0, furniture=0, magic=0, time='night', weather='rain')
            exchange(data[cid], 'meeting', state)
            assert not state['items'], cid + ': reward at first meeting'
            assert exchange(data[cid], 'festival', state), cid + ': no festival dispatch'
            for _ in range(2): exchange(data[cid], 'quest', state)
            assert q['id'] + '_prepared' in state['flags'] and not state['items'], cid + ': isolated preparation/reward'
            state['flags'].add(q['event'])
            exchange(data[cid], 'quest', state)
            assert q['id'] + '_done' in state['flags'] and state['items'] == {q['reward']}, cid + ': isolated completion'
            checks += 1
    # Omit each main objective in turn, including the prior chapter.
    for quest in manifest['main_quests']:
        for callback in (False, True):
            base = dict(flags={'met_' + c for c in data} | events | {q['id'] + '_done' for q in manifest['main_quests'] if q['id'] != quest['id']} | {quest['id'] + '_accepted'}, items=set(), visited=set(locations), garden=3, furniture=1, magic=0, time='day', weather='clear')
            if callback: base['flags'].add('q_' + quest['owner'] + '_done')
            for condition in quest['conditions']:
                state = copy.deepcopy(base)
                key, value = next(iter(condition.items()))
                if key == 'flag': state['flags'].discard(value)
                elif key == 'visited': state['visited'].discard(value)
                else: state[{'garden_planted_gte': 'garden', 'furniture_placed_gte': 'furniture'}[key]] = value - 1
                exchange(data[quest['owner']], 'main', state)
                assert quest['id'] + '_done' not in state['flags'], quest['id'] + ': missing objective allowed completion'
                checks += 1
        if quest['prerequisite']:
            state = copy.deepcopy(base)
            state['flags'].difference_update({quest['prerequisite'], quest['id'] + '_accepted'})
            exchange(data[quest['owner']], 'main', state)
            assert quest['id'] + '_accepted' not in state['flags'], quest['id'] + ': prerequisite skipped'
            checks += 1
    return checks


def main():
    if not __debug__:
        print('FAIL run without -O or PYTHONOPTIMIZE; progression assertions must remain active')
        return 1
    try:
        manifest = read(ROOT / 'story_manifest.json')
        data = {path.stem: read(path) for path in sorted((ROOT / 'dialogue').glob('*.json'))}
        errors = validate(data, manifest)
        if errors:
            print('\n'.join('FAIL ' + e for e in errors)); return 1
        cases = simulate(data, manifest)
        broken = copy.deepcopy(data)
        first = next(iter(broken))
        broken[first]['nodes'][0]['next'] = 'missing_target'
        assert any('unresolved next' in e for e in validate(broken, manifest)), 'negative link check failed'
        broken = copy.deepcopy(data)
        broken[first]['nodes'][0]['effects'] = [{'set_flag': next(iter(manifest['world_events'])), 'value': True}]
        assert any('forbidden/invalid effect' in e for e in validate(broken, manifest)), 'negative event check failed'
        broken = copy.deepcopy(data)
        reward = next(c['quest']['reward'] for c in manifest['characters'] if c['id'] == first)
        broken[first]['nodes'][0]['effects'] = [{'give_item': reward}]
        assert any('reward/completion' in e for e in validate(broken, manifest)), 'negative early-reward check failed'
        broken = copy.deepcopy(data)
        for node in broken['ombel']['nodes']:
            if node['id'] in ('ombel_m_agreement_ready', 'ombel_m_agreement_callback'):
                node['conditions'] = [c for c in node['conditions'] if c != {'flag': 'e_water_plan_shared'}]
        try:
            simulate(broken, manifest)
        except AssertionError:
            pass
        else:
            raise ValueError('negative main-event gate check failed')
        count = sum(len(doc['nodes']) for doc in data.values())
        print(f'PASS {len(data)} characters; {len(data)} JSON files; {count} dialogue nodes; {len(data) + len(manifest["main_quests"])} quests')
        print('PASS JSON parsing, unique keys/IDs, schema, expressions, links, structural reachability, greeting coverage')
        print(f'PASS {cases} progression checks: eight sky pairs, zero magic, defer/reopen, isolated side quests before/after finale, main prerequisites/objectives')
        print('PASS 4 in-memory negative checks: dangling link, forbidden event write, early reward, and missing main-event gate rejected')
        print('SCOPE authoring data only; no Godot, runtime, manual-play, audio, motion or device validation')
        return 0
    except (OSError, ValueError, KeyError, TypeError, AssertionError) as error:
        print(f'FAIL {error}'); return 1


if __name__ == '__main__':
    sys.exit(main())
