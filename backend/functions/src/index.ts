// Cloud Functions for Cat Paws Arena (europe-west1). Prepared by lane 5;
// only the owner deploys them.
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as v1 from "firebase-functions/v1";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

const region = "europe-west1";
initializeApp();
setGlobalOptions({ region, maxInstances: 10 });

const DELETED = "deleted";

/**
 * Account deletion, server side. The app deletes the profile, devices and
 * rooms, then the Auth user; this removes anything left and anonymizes
 * matches the client may not edit.
 */
export const onUserDeleted = v1
  .region(region)
  .auth.user()
  .onDelete(async (user) => {
    const db = getFirestore();
    const uid = user.uid;
    await db.recursiveDelete(db.doc(`users/${uid}`));
    await db.doc(`clocks/${uid}`).delete();
    const rooms = await db.collection("rooms").where("hostUid", "==", uid).get();
    await Promise.all(rooms.docs.map((d) => d.ref.delete()));
    for (const field of ["hostUid", "guestUid"]) {
      const matches = await db.collection("matches").where(field, "==", uid).get();
      for (const match of matches.docs) {
        await match.ref.update({ [field]: DELETED });
        const emotes = await match.ref.collection("emotes").where("from", "==", uid).get();
        await Promise.all(emotes.docs.map((e) => e.ref.update({ from: DELETED })));
      }
    }
  });

/**
 * Your-turn push to every device of [recipientUid]. The payload carries only
 * the match ID; the text comes from the app's string resources.
 */
export async function notifyTurn(matchId: string, recipientUid: string) {
  if (recipientUid === DELETED) return;
  const db = getFirestore();
  const devices = await db.collection(`users/${recipientUid}/devices`).get();
  await Promise.all(
    devices.docs.map(async (device) => {
      const fid = device.get("fid");
      if (typeof fid !== "string") return;
      try {
        await getMessaging().send({
          fid,
          data: { matchId },
          android: {
            priority: "high",
            notification: {
              titleLocKey: "cpa_turn_title",
              bodyLocKey: "cpa_turn_body",
              channelId: "your_turn",
            },
          },
        });
      } catch (error) {
        const code = (error as { code?: string }).code;
        if (code === "messaging/registration-token-not-registered") {
          await device.ref.delete();
        } else {
          throw error;
        }
      }
    }),
  );
}

/** A move document names its sender in `by`; the other player gets the push. */
export const onMoveCreated = onDocumentCreated(
  "matches/{matchId}/moves/{moveId}",
  async (event) => {
    const by = event.data?.get("by");
    const match = await getFirestore().doc(`matches/${event.params.matchId}`).get();
    if (!match.exists || typeof by !== "string") return;
    const host = match.get("hostUid");
    const guest = match.get("guestUid");
    const recipient = by === host ? guest : by === guest ? host : null;
    if (typeof recipient === "string") await notifyTurn(match.id, recipient);
  },
);
