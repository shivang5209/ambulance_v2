const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ── DBSCAN helpers ────────────────────────────────────────────────────

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function dbscan(points, eps_km = 0.3, minPts = 3) {
  const n = points.length;
  const labels = new Array(n).fill(-1);
  let clusterId = 0;

  const regionQuery = (idx) => {
    const neighbours = [];
    for (let i = 0; i < n; i++) {
      if (haversineKm(points[idx].lat, points[idx].lng, points[i].lat, points[i].lng) <= eps_km) {
        neighbours.push(i);
      }
    }
    return neighbours;
  };

  for (let i = 0; i < n; i++) {
    if (labels[i] !== -1) continue;
    const neighbours = regionQuery(i);
    if (neighbours.length < minPts) { labels[i] = 0; continue; }
    clusterId++;
    labels[i] = clusterId;
    const seed = neighbours.filter((j) => j !== i);
    while (seed.length > 0) {
      const j = seed.pop();
      if (labels[j] === 0) labels[j] = clusterId;
      if (labels[j] !== -1) continue;
      labels[j] = clusterId;
      const jNeighbours = regionQuery(j);
      if (jNeighbours.length >= minPts) seed.push(...jNeighbours);
    }
  }

  const clusters = {};
  for (let i = 0; i < n; i++) {
    const c = labels[i];
    if (c <= 0) continue;
    if (!clusters[c]) clusters[c] = [];
    clusters[c].push(points[i]);
  }
  return Object.values(clusters);
}

// ── hotspotAnalysis — runs every 15 minutes ───────────────────────────

exports.hotspotAnalysis = functions.pubsub
  .schedule("every 15 minutes")
  .onRun(async () => {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    // 1. Pull recent accident & near-miss events (last 90 days)
    const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    const snap = await db
      .collection("accident_events")
      .where("true_label", "in", ["accident", "near_miss"])
      .where("detectionTime", ">=", admin.firestore.Timestamp.fromDate(cutoff))
      .get();

    if (snap.empty) return null;

    const points = snap.docs.map((doc) => {
      const d = doc.data();
      return {
        lat: d.location?.latitude ?? d.location?.lat ?? 0,
        lng: d.location?.longitude ?? d.location?.lng ?? 0,
        severity: d.severity_level ?? 2,
        time: d.detectionTime?.toDate() ?? new Date(),
        id: doc.id,
      };
    });

    // 2. Run DBSCAN (eps=0.3 km ≈ 300 m, minPts=3)
    const clusters = dbscan(points, 0.3, 3);
    functions.logger.info(`Found ${clusters.length} clusters from ${points.length} events`);

    const batch = db.batch();

    for (const cluster of clusters) {
      const avgLat = cluster.reduce((s, p) => s + p.lat, 0) / cluster.length;
      const avgLng = cluster.reduce((s, p) => s + p.lng, 0) / cluster.length;
      const avgSeverity = cluster.reduce((s, p) => s + (p.severity ?? 2), 0) / cluster.length;

      // Compute peak hours
      const hourCounts = {};
      cluster.forEach((p) => {
        const h = p.time.getHours();
        hourCounts[h] = (hourCounts[h] ?? 0) + 1;
      });
      const peakHour = Object.entries(hourCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "unknown";
      const peakHours = [`${peakHour}:00`];

      // 3. Gemini analysis
      const prompt = `You are a road safety AI. Analyze this accident hotspot in India (max 120 words):
- Incidents: ${cluster.length} in 90 days
- Avg severity (1-4): ${avgSeverity.toFixed(1)}
- GPS: ${avgLat.toFixed(4)}, ${avgLng.toFixed(4)}
- Peak hour: ${peakHour}:00
Give: likely root causes, risk window, one ambulance pre-positioning recommendation.`;

      let geminiAnalysis = "";
      try {
        const result = await model.generateContent(prompt);
        geminiAnalysis = result.response.text();
      } catch (e) {
        functions.logger.warn("Gemini API error:", e.message);
      }

      const zoneId = `zone_${Math.round(avgLat * 1000)}_${Math.round(avgLng * 1000)}`;
      const ref = db.collection("hotspots").doc(zoneId);

      batch.set(
        ref,
        {
          centerLat: avgLat,
          centerLng: avgLng,
          radiusMeters: 300,
          incidentCount: cluster.length,
          avgSeverity,
          peakHours,
          peakDays: [],
          weatherFactor: "unknown",
          trend: "stable",
          geminiAnalysis,
          ambulanceRecommendation: {},
          isActive: true,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // 5. FCM push to nearby drivers if critical new hotspot
      if (avgSeverity >= 3.5 && cluster.length >= 5) {
        try {
          await messaging.sendToTopic("driver_alerts", {
            notification: {
              title: "⚠️ New Critical Hotspot Detected",
              body: `${cluster.length} incidents near (${avgLat.toFixed(3)}, ${avgLng.toFixed(3)}). Stay alert.`,
            },
            data: { zoneId, lat: String(avgLat), lng: String(avgLng) },
          });
        } catch (e) {
          functions.logger.warn("FCM push failed:", e.message);
        }
      }
    }

    await batch.commit();
    functions.logger.info(`Updated ${clusters.length} hotspot zones`);
    return null;
  });

// ── weeklyDriftCheck — every Monday 09:00 IST ─────────────────────────

exports.weeklyDriftCheck = functions.pubsub
  .schedule("every monday 09:00")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const snap = await db
      .collection("training_data")
      .where("labeled_at", ">=", admin.firestore.Timestamp.fromDate(cutoff))
      .where("ready_for_training", "==", true)
      .get();

    if (snap.empty) return null;

    let total = 0, falsePositives = 0, confirmed = 0;
    snap.docs.forEach((doc) => {
      const d = doc.data();
      total++;
      if (d.true_label === "false_positive") falsePositives++;
      if (d.true_label === "accident" || d.true_label === "near_miss") confirmed++;
    });

    const fpr = total > 0 ? falsePositives / total : 0;
    const precision = confirmed + falsePositives > 0
      ? confirmed / (confirmed + falsePositives)
      : 1.0;

    const weekId = new Date().toISOString().split("T")[0];
    await db.collection("model_health").doc(weekId).set({
      week: weekId,
      total_labeled: total,
      false_positives: falsePositives,
      confirmed_accidents: confirmed,
      fpr: Math.round(fpr * 10000) / 10000,
      precision: Math.round(precision * 10000) / 10000,
      computed_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`Drift check: FPR=${(fpr * 100).toFixed(1)}%, Precision=${(precision * 100).toFixed(1)}%`);

    // Alert admin if FPR > 20%
    if (fpr > 0.20) {
      try {
        await messaging.sendToTopic("admin_alerts", {
          notification: {
            title: "🔴 Model Drift Alert",
            body: `False Positive Rate is ${(fpr * 100).toFixed(1)}% this week. Retraining recommended.`,
          },
          data: { fpr: String(fpr), precision: String(precision) },
        });
      } catch (e) {
        functions.logger.warn("FCM admin push failed:", e.message);
      }
    }

    return null;
  });
