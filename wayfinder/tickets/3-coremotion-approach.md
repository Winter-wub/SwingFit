## Question

For CoreMotion swing analysis, how should we approach detecting and classifying pickleball swings (forehand/backhand) from accelerometer/gyroscope data? Should we use basic thresholding, or a CoreML model trained on collected motion data?

Labels: wayfinder:research
Status: closed

## Resolution

Based on research, we will use a **CoreML (Machine Learning)** approach rather than basic thresholding. Thresholding is too brittle and generates false positives for varying swing styles. 

**Next Steps**: 
1. Build a simple data collection tool within the app to log CoreMotion data (accelerometer/gyroscope) to CSV files.
2. Manually label the data (Forehand, Backhand, Idle).
3. Use Apple's Create ML app (Activity Classification template) to train an `.mlmodel`.
4. Integrate the `.mlmodel` into the Watch app for real-time inference.
