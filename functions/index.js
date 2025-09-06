const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

/**
 * Callable: createAdminAccount
 * data: { name, email, password, phone?, role }  // role: super|manager|staff
 */
exports.createAdminAccount = functions.https.onCall(async (data, context) => {
  try {
    const callerUid = context.auth?.uid;
    if (!callerUid) {
      throw new functions.https.HttpsError('unauthenticated', 'Harus login.');
    }

    const callerSnap = await db.collection('admins').doc(callerUid).get();
    if (!callerSnap.exists || callerSnap.get('isActive') !== true) {
      throw new functions.https.HttpsError('permission-denied', 'Bukan admin aktif.');
    }
    const callerRole = (callerSnap.get('role') || '').toString(); // super|manager|staff

    const name = (data?.name || '').toString().trim();
    const email = (data?.email || '').toString().trim().toLowerCase();
    const password = (data?.password || '').toString();
    const phone = (data?.phone || '').toString().trim();
    const role = (data?.role || 'staff').toString(); // default staff

    if (!name || !email || !password) {
      throw new functions.https.HttpsError('invalid-argument', 'Nama, email, password wajib.');
    }
    if (!['super', 'manager', 'staff'].includes(role)) {
      throw new functions.https.HttpsError('invalid-argument', 'Role tidak valid.');
    }

    // Role guard: manager hanya boleh membuat staff; staff ditolak
    if (callerRole === 'manager' && role !== 'staff') {
      throw new functions.https.HttpsError('permission-denied', 'Manager hanya boleh membuat staff.');
    }
    if (callerRole === 'staff') {
      throw new functions.https.HttpsError('permission-denied', 'Staff tidak boleh membuat admin.');
    }

    // Buat user di Auth
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: name,
      // phoneNumber optional; pastikan format E.164 kalau dipakai
      // phoneNumber: phone ? phone : undefined,
    });

    // Simpan di Firestore
    await db.collection('admins').doc(userRecord.uid).set({
      name,
      email,
      phone: phone || null,
      role,                  // super | manager | staff
      isActive: true,
      isRoot: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid,
    });

    return { ok: true, uid: userRecord.uid };
  } catch (err) {
    console.error('createAdminAccount error:', err);
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('internal', err.message || 'Gagal membuat admin');
  }
});

/**
 * Trigger: hapus user Auth saat dokumen admin dihapus (kecuali root)
 */
exports.onAdminDeleted = functions.firestore
  .document('admins/{adminId}')
  .onDelete(async (snap, context) => {
    const adminId = context.params.adminId;
    const isRoot = snap.get('isRoot') === true;

    if (isRoot) {
      console.log('Root admin dihapus di Firestore, tetapi tidak akan menghapus user Auth.');
      return null;
    }

    try {
      await admin.auth().deleteUser(adminId);
      console.log(`Auth user ${adminId} deleted.`);
    } catch (e) {
      console.error('deleteUser error:', e);
    }
    return null;
  });

/**
 * OPTIONAL: bootstrap root admin kalau mau dipanggil manual
 * (Biasanya kamu sudah login pakai root email lalu app menandai isRoot=true)
 */
exports.bootstrapRoot = functions.https.onCall(async (data, context) => {
  const callerUid = context.auth?.uid;
  if (!callerUid) {
    throw new functions.https.HttpsError('unauthenticated', 'Harus login.');
  }
  const user = await admin.auth().getUser(callerUid);
  const email = (user.email || '').toLowerCase();

  // ganti email root sesuai kebutuhan
  const ROOT_EMAIL = 'admin@sipkabel.com';
  if (email !== ROOT_EMAIL) {
    throw new functions.https.HttpsError('permission-denied', 'Bukan root email.');
  }

  await db.collection('admins').doc(callerUid).set({
    name: user.displayName || 'Super Admin',
    email,
    phone: null,
    role: 'super',
    isActive: true,
    isRoot: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true };
});
