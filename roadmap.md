# 🏀 Vertical Jump App — Development Roadmap
**Stack:** Flutter (mobile) + Python (FastAPI + ML backend)

---

## Phase 0 — Project Setup (Week 0–1)
**Goal:** Create a working foundation

- [ ] Create Flutter app (iOS + Android)
- [ ] Set up GitHub repo + CI
- [ ] Configure Android & iOS permissions (camera, storage)
- [ ] Set up FastAPI backend skeleton
- [ ] Choose cloud (AWS or GCP)
- [ ] Create Firebase project (Auth, Storage, Analytics)

---

## Phase 1 — Camera & Pose (Week 1–2)
**Goal:** Get real-time pose running on the phone

- [ ] Integrate Flutter camera stream
- [ ] Add FFmpeg preprocessing (FPS, orientation, trim)
- [ ] Integrate MoveNet or MediaPipe Pose via TFLite
- [ ] Run pose inference on every frame
- [ ] Draw skeleton overlay on video
- [ ] Log keypoints per frame

Deliverable:  
**User sees skeleton tracking in real time**

---

## Phase 2 — Motion Smoothing & Tracking (Week 2–3)
**Goal:** Stable and reliable pose tracking

- [ ] Implement One-Euro or Kalman filter
- [ ] Track pelvis + ankle positions over time
- [ ] Handle missing / low-confidence frames
- [ ] Build frame buffer (time-series)
- [ ] Detect when jump starts & ends

Deliverable:  
**Clean position curves for hips and feet**

---

## Phase 3 — Jump Detection (Week 3–4)
**Goal:** Identify takeoff, peak, and landing

- [ ] Define ground plane from feet
- [ ] Detect takeoff frame (feet leave ground)
- [ ] Detect landing frame (feet contact ground)
- [ ] Detect peak COM (pelvis highest point)
- [ ] Compute vertical displacement

Deliverable:  
**Jump height in pixels**

---

## Phase 4 — Real-World Scaling (Week 4–5)
**Goal:** Convert pixels → inches/cm

- [ ] Integrate ARKit / ARCore ground plane
- [ ] Fallback to user height calibration
- [ ] Handle camera tilt & perspective
- [ ] Compute real-world jump height

Deliverable:  
**Jump height in inches / cm**

---

## Phase 5 — UI & User Experience (Week 5–6)
**Goal:** Make it feel like a real sports app

- [ ] Jump replay with skeleton overlay
- [ ] Graph of jump height over time
- [ ] Confidence indicator
- [ ] “Retake jump” guidance
- [ ] Camera placement tips

Deliverable:  
**Usable training tool**

---

## Phase 6 — Cloud Sync (Optional) (Week 6–7)
**Goal:** Save jumps & enable reprocessing

- [ ] Firebase Auth (users)
- [ ] Firestore (jump history)
- [ ] Firebase Storage (videos)
- [ ] Upload jump metadata

Deliverable:  
**User accounts + saved jumps**

---

## Phase 7 — ML Backend (Week 7–9)
**Goal:** High-accuracy reprocessing

- [ ] FastAPI upload endpoint
- [ ] Video ingestion
- [ ] FFmpeg processing
- [ ] MMPose inference
- [ ] Better jump detection
- [ ] Return improved result

Deliverable:  
**Server-grade jump accuracy**

---

## Phase 8 — Accuracy & Validation (Week 9–10)
**Goal:** Make results trustworthy

- [ ] Test on multiple people
- [ ] Compare to real measurement tools
- [ ] Tune thresholds & filters
- [ ] Add error detection (bad angles, occlusion)

Deliverable:  
**Production-ready measurement**

---

## Phase 9 — Scale & Monetize (Future)
**Goal:** Turn into a real platform

- [ ] Premium reprocessing
- [ ] 3D pose
- [ ] Force & power estimation
- [ ] Athlete profiles
- [ ] Team dashboards

---

## 🥇 End Result

A professional-grade mobile system that:
- Measures vertical jump in real time
- Re-analyzes for lab-grade accuracy
- Scales to thousands of athletes


## Stretch Goals
- Real-time form feedback (live camera stream).
- Team dashboard for coaches.
- Personalized training recommendations (AI-based).
