// Firestore security rules tests. Run with `npm run test:rules` (local
// emulator, demo project; nothing is deployed).
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-cat-paws-arena',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const hours = (h) => Timestamp.fromMillis(Date.now() + h * 3600e3);

const profile = (over = {}) => ({
  schemaVersion: 1,
  revision: 1,
  trophies: 0,
  coins: 0,
  cat: 'Tzuki',
  accessory: '',
  fur: 0,
  eyes: 0,
  ears: 1,
  pattern: 0,
  power: 0,
  owned: [],
  claims: [],
  daily: '',
  sfx: true,
  music: true,
  english: false,
  notifications: true,
  ...over,
});

async function hostRoom(code = 'ABC234', uid = 'host') {
  const h = db(uid);
  await assertSucceeds(
    setDoc(doc(h, 'rooms', code), {
      hostUid: uid,
      createdAt: serverTimestamp(),
      expiresAt: hours(24),
    }),
  );
  return (await getDoc(doc(h, 'rooms', code))).data();
}

const matchIdOf = (code, room) => `${code}_${room.createdAt.toMillis()}`;

// What FirestoreCloudStore.claimRoom does.
function claim(code, uid) {
  const g = db(uid);
  return runTransaction(g, async (tx) => {
    const snap = await tx.get(doc(g, 'rooms', code));
    if (!snap.exists()) throw new Error('room gone');
    const room = snap.data();
    const id = matchIdOf(code, room);
    tx.set(doc(g, 'matches', id), {
      roomCode: code,
      hostUid: room.hostUid,
      guestUid: uid,
      createdAt: serverTimestamp(),
    });
    tx.delete(doc(g, 'rooms', code));
    return id;
  });
}

async function seedMatch() {
  await hostRoom();
  return claim('ABC234', 'guest');
}

describe('default deny', () => {
  test('signed-out users read nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'users', 'host')));
    await assertFails(getDoc(doc(anon(), 'rooms', 'ABC234')));
  });
  test('unknown collections are closed', async () => {
    await assertFails(setDoc(doc(db('a'), 'chat', 'x'), { text: 'hi' }));
    await assertFails(setDoc(doc(db('a'), 'events', 'x'), { name: 'x' }));
  });
});

describe('users (cloud save)', () => {
  test('owner creates, reads and deletes; others cannot read', async () => {
    await assertSucceeds(setDoc(doc(db('a'), 'users', 'a'), profile()));
    await assertSucceeds(getDoc(doc(db('a'), 'users', 'a')));
    await assertFails(getDoc(doc(db('b'), 'users', 'a')));
    await assertFails(setDoc(doc(db('b'), 'users', 'a'), profile()));
    await assertSucceeds(deleteDoc(doc(db('a'), 'users', 'a')));
  });
  test('revision must go up by exactly one', async () => {
    const ref = doc(db('a'), 'users', 'a');
    await assertFails(setDoc(ref, profile({ revision: 2 })));
    await assertSucceeds(setDoc(ref, profile()));
    await assertFails(setDoc(ref, profile({ revision: 1 })));
    await assertFails(setDoc(ref, profile({ revision: 3 })));
    await assertSucceeds(setDoc(ref, profile({ revision: 2 })));
  });
  test('accepts every cat-creator option, rejects anything past it', async () => {
    const ref = doc(db('a'), 'users', 'a');
    await assertSucceeds(
      setDoc(ref, profile({ cat: 'Custom', fur: 5, eyes: 3, ears: 3, pattern: 4, power: 2 })),
    );
    for (const bad of [
      { fur: 6 }, { eyes: 4 }, { ears: 4 }, { pattern: 5 }, { power: 3 },
      { fur: -1 }, { trophies: -1 }, { coins: '5' }, { cat: 'Unknown' },
      { schemaVersion: 2 }, { accessory: 'x'.repeat(65) }, { daily: 'a\nb' },
      { sfx: 1 },
    ]) {
      await assertFails(setDoc(ref, profile({ revision: 2, ...bad })), JSON.stringify(bad));
    }
  });
  test('no typed name, photo or other extra field can be stored', async () => {
    const ref = doc(db('a'), 'users', 'a');
    await assertFails(setDoc(ref, profile({ name: 'Alex' })));
    await assertFails(setDoc(ref, profile({ photo: 'x' })));
    const { owned, ...missing } = profile();
    await assertFails(setDoc(ref, missing));
  });
});

describe('devices (push)', () => {
  const id = 'abcdefghij0123456789';
  test('owner stores a Firebase installation ID with server time', async () => {
    const ref = doc(db('a'), 'users', 'a', 'devices', id);
    await assertSucceeds(
      setDoc(ref, { fid: 'fid-1', platform: 'android', updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(getDocs(collection(db('a'), 'users', 'a', 'devices')));
    await assertFails(getDoc(doc(db('b'), 'users', 'a', 'devices', id)));
  });
  test('rejects extra fields, client time and other users', async () => {
    const ok = { fid: 'f', platform: 'android', updatedAt: serverTimestamp() };
    await assertFails(setDoc(doc(db('a'), 'users', 'a', 'devices', id), { ...ok, name: 'x' }));
    await assertFails(
      setDoc(doc(db('a'), 'users', 'a', 'devices', id), { ...ok, updatedAt: Timestamp.now() }),
    );
    await assertFails(setDoc(doc(db('b'), 'users', 'a', 'devices', id), ok));
    await assertFails(setDoc(doc(db('a'), 'users', 'a', 'devices', 'Bad/Id!'.slice(0, 3)), ok));
  });
});

describe('clocks', () => {
  test('only server time, only own document', async () => {
    await assertSucceeds(setDoc(doc(db('a'), 'clocks', 'a'), { t: serverTimestamp() }));
    await assertFails(setDoc(doc(db('a'), 'clocks', 'a'), { t: Timestamp.now() }));
    await assertFails(setDoc(doc(db('b'), 'clocks', 'a'), { t: serverTimestamp() }));
  });
});

describe('rooms', () => {
  test('host creates a valid room; code, owner and times are checked', async () => {
    await hostRoom();
    const h = db('host');
    const base = { hostUid: 'host', createdAt: serverTimestamp(), expiresAt: hours(24) };
    await assertFails(setDoc(doc(h, 'rooms', 'ABCO12'), base)); // O and 1 excluded
    await assertFails(setDoc(doc(h, 'rooms', 'ABC23'), base));
    await assertFails(setDoc(doc(h, 'rooms', 'XYZ234'), { ...base, hostUid: 'other' }));
    await assertFails(setDoc(doc(h, 'rooms', 'XYZ234'), { ...base, createdAt: Timestamp.now() }));
    await assertFails(setDoc(doc(h, 'rooms', 'XYZ234'), { ...base, expiresAt: hours(48) }));
    await assertFails(setDoc(doc(h, 'rooms', 'XYZ234'), { ...base, note: 'hi' }));
  });
  test('no updates; only own rooms can be listed', async () => {
    await hostRoom();
    await assertFails(updateDoc(doc(db('host'), 'rooms', 'ABC234'), { expiresAt: hours(24) }));
    await assertFails(getDocs(collection(db('x'), 'rooms')));
    await assertSucceeds(
      getDocs(query(collection(db('host'), 'rooms'), where('hostUid', '==', 'host'))),
    );
    await assertSucceeds(getDoc(doc(db('x'), 'rooms', 'ABC234')));
  });
  test('a stranger cannot delete a live room; the host can', async () => {
    await hostRoom();
    await assertFails(deleteDoc(doc(db('x'), 'rooms', 'ABC234')));
    await assertSucceeds(deleteDoc(doc(db('host'), 'rooms', 'ABC234')));
  });
});

describe('room claim', () => {
  test('a guest claims a room: match created, room gone', async () => {
    const id = await assertSucceeds(seedMatch());
    const m = await getDoc(doc(db('host'), 'matches', id));
    assert.equal(m.data().guestUid, 'guest');
    assert.equal((await getDoc(doc(db('x'), 'rooms', 'ABC234'))).exists(), false);
  });
  test('three guests at once: exactly one match', async () => {
    const room = await hostRoom();
    const results = await Promise.allSettled(['g1', 'g2', 'g3'].map((g) => claim('ABC234', g)));
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    let exists = false;
    await env.withSecurityRulesDisabled(async (ctx) => {
      exists = (await getDoc(doc(ctx.firestore(), 'matches', matchIdOf('ABC234', room)))).exists();
    });
    assert.ok(exists);
  });
  test('host cannot claim own room', async () => {
    await hostRoom();
    await assertFails(claim('ABC234', 'host'));
  });
  test('match without deleting the room, wrong ID, or spoofed guest fails', async () => {
    const room = await hostRoom();
    const g = db('guest');
    const id = matchIdOf('ABC234', room);
    const data = { roomCode: 'ABC234', hostUid: 'host', guestUid: 'guest', createdAt: serverTimestamp() };
    await assertFails(setDoc(doc(g, 'matches', id), data));
    const wrong = writeBatch(g);
    wrong.set(doc(g, 'matches', 'ABC234_1'), data);
    wrong.delete(doc(g, 'rooms', 'ABC234'));
    await assertFails(wrong.commit());
    const spoof = writeBatch(g);
    spoof.set(doc(g, 'matches', id), { ...data, guestUid: 'someone' });
    spoof.delete(doc(g, 'rooms', 'ABC234'));
    await assertFails(spoof.commit());
    await assertFails(deleteDoc(doc(g, 'rooms', 'ABC234')));
  });
  test('an expired room cannot be claimed, anyone may delete it', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'rooms', 'OLD234'), {
        hostUid: 'host',
        createdAt: hours(-25),
        expiresAt: hours(-1),
      });
    });
    await assertFails(claim('OLD234', 'guest'));
    await assertSucceeds(deleteDoc(doc(db('x'), 'rooms', 'OLD234')));
  });
});

describe('matches and emotes', () => {
  test('only the two players read a match; nobody edits it', async () => {
    const id = await seedMatch();
    await assertSucceeds(getDoc(doc(db('host'), 'matches', id)));
    await assertSucceeds(getDoc(doc(db('guest'), 'matches', id)));
    await assertFails(getDoc(doc(db('x'), 'matches', id)));
    await assertFails(getDocs(collection(db('host'), 'matches')));
    await assertFails(updateDoc(doc(db('host'), 'matches', id), { guestUid: 'x' }));
    await assertFails(deleteDoc(doc(db('host'), 'matches', id)));
  });
  test('the host can watch a match ID before it exists', async () => {
    await assertSucceeds(getDoc(doc(db('host'), 'matches', 'ABC234_123')));
  });
  test('preset emotes only, from yourself, players only', async () => {
    const id = await seedMatch();
    const emotes = (uid) => collection(db(uid), 'matches', id, 'emotes');
    const ok = (uid, emote = 'purr') => ({ emote, from: uid, at: serverTimestamp() });
    await assertSucceeds(addDoc(emotes('guest'), ok('guest')));
    await assertSucceeds(getDocs(emotes('host')));
    await assertFails(addDoc(emotes('guest'), ok('guest', 'hi there')));
    await assertFails(addDoc(emotes('guest'), ok('host')));
    await assertFails(addDoc(emotes('guest'), { ...ok('guest'), text: 'hi' }));
    await assertFails(addDoc(emotes('x'), ok('x')));
    await assertFails(getDocs(emotes('x')));
  });
});
