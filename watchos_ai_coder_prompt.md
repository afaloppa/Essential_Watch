# WatchOS Accelerometer Detection App – AI Coding Prompt

I have a repository for a WatchOS application for Apple Watch. The goal of the app is to eventually use accelerometer sensor data to predict a specific event using a machine learning model. The ML model is not implemented yet, so for now I only want to build the application infrastructure and UI for data acquisition.

## Requirements

### 1. Platform and Language
- Build a native WatchOS application.
- Use Swift and SwiftUI.
- Follow modern Apple development practices and proper project structure.

### 2. Core Functionality
Create a simple user interface with:
- A “Start Detection” button
- A “Stop Detection” button
- A visual indicator showing whether detection is currently active or inactive

When detection is active:
- Start reading accelerometer data continuously using CoreMotion.
- Store or stream the accelerometer values in memory for future ML integration.

When detection is stopped:
- Stop accelerometer updates immediately.
- Update the UI state accordingly.

### 3. Architecture
Implement clean separation between:
- UI layer
- Motion sensor manager/service
- Future ML prediction pipeline

Design the code so an ML model can later be plugged into the accelerometer data stream easily.

### 4. Additional Requirements
- Include proper permissions and handling for motion sensor access if required.
- Ensure the app is optimized for Apple Watch battery constraints.
- Add comments and documentation throughout the code.
- Include error handling for unavailable sensors or motion access failures.
- Use observable state management so the UI updates reactively.

### 5. Future Extensibility
Prepare placeholders/interfaces for:
- Real-time prediction
- Data logging
- Background monitoring
- Sending predictions/results to iPhone companion app

### 6. Deliverables
- Complete SwiftUI WatchOS app structure
- MotionManager class/service using CoreMotion
- Example implementation for starting/stopping accelerometer acquisition
- Minimal but clean Apple Watch UI
- Explanation of file structure and architecture choices

## Notes
The application does not yet need any machine learning inference. The current goal is only:
- UI interaction
- Motion sensor acquisition
- Clean architecture ready for ML integration later

Use production-quality Swift code with comments and modular design.
