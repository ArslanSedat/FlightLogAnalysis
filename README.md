# Flight Log Analysis Application

## Overview

This MATLAB App Designer project implements a modular *Flight Log Analysis Application* that allows the visualization, organization, and analysis of flight data through an interactive graphical interface.

The app provides:
- Multi-figure management (dynamic figure creation)
- Multi-axes management (line or scatter plots)
- A panner view for flight altitude visualization
- A hierarchical tree view for managing figures and axes
- Export features (`.png`, `.fig`)
- Data loading and plotting capabilities via external helper classes

All visual and logical components are cleanly separated to ensure readability and maintainability.

---

## Project Structure

/FlightLogAnalysisApp

data/ # Contains datasets that can be uploaded inside the application
src/SupportFunctions.m # Static class with all functional logic
src/FlightDataManager.m # Operations allowing plotting from dataset values
FlightLogAnalysisApplication.mlapp # Main App Designer interface
README.md # Documentation (this file)

## How to Run the App

1. Open MATLAB.
2. Navigate to *FlightLogAnalysisApplication.mlapp*.
3. Double-click on the file.
4. App Designer opens.
5. Click on **Run** button at the top.

## Equations Used

The application computes multiple aerodynamic and kinematic parameters using data typically found in UAV or flight test logs.  
The equations below correspond directly to the methods implemented in *FlightDataManager.m*.

### 1. Quaternion -> Euler Angles Conversion
Used to obtain yaw (ψ), pitch (θ), and roll (φ) from IMU quaternion data:

\[
\begin{bmatrix}
\psi \\ \theta \\ \phi
\end{bmatrix}
= \text{quat2eul}(q_{e0}, q_{ex}, q_{ey}, q_{ez}, 'ZYX')
\]

Resulting variables:
- *yaw_rad*, *pitch_rad*, *roll_rad*

### 2. Geodetic (LLA) -> Local NED Coordinates
Using the reference latitude/longitude/altitude \((lat_0, lon_0, alt_0)\):

\[
\begin{aligned}
north_m &= (lat_{rad} - lat_0) \cdot R \\
east_m &= (lon_{rad} - lon_0) \cdot R \cdot \cos(lat_0) \\
down_m &= -(alt_m - alt_0)
\end{aligned}
\]

where \( R = 6378137 \, m \) (Earth radius).

### 3. Body Frame Velocities
Derived from true airspeed and angles of attack (α) and sideslip (β):

\[
\begin{aligned}
u &= V_T \cdot \cos(\alpha) \cdot \cos(\beta) \\
v &= V_T \cdot \sin(\beta) \\
w &= V_T \cdot \sin(\alpha) \cdot \cos(\beta)
\end{aligned}
\]

Resulting variables:
- *u_m_s*, *v_m_s*, *w_m_s*

### 4. Aerodynamic Coefficients
Lift (CL), Drag (CD), and Side Force (CY) coefficients are calculated as:

\[
q = \tfrac{1}{2} \rho V_T^2
\]

\[
\begin{aligned}
C_L &= \frac{m (a_z + g)}{q S} \\
C_D &= \frac{m a_x - T}{q S} \\
C_Y &= \frac{m a_y}{q S}
\end{aligned}
\]

where:
- \( m \): aircraft mass (kg)  
- \( a_x, a_y, a_z \): accelerations (m/s²)  
- \( T \): thrust (N)  
- \( S \): wing area (m²)  
- \( \rho \): air density from `atmoscoesa()`  
- \( g = 9.80665 \, m/s^2 \)

### 5. Aerodynamic Forces
Once coefficients are known, the forces in Newtons are computed as:

\[
\begin{aligned}
L &= q S C_L \\
D &= q S C_D \\
Y &= q S C_Y
\end{aligned}
\]

Resulting variables:
- *Lift_N*, *Drag_N*, *SideForce_N*

### 6. Air Density Model (ISA)
Computed via the built-in MATLAB function:

\[
\rho = f(altitude) = \text{atmo}(alt_m)
\]

This follows the standard atmosphere model (ISA) for temperature, pressure, and density variation with altitude.

### 7. Unit Conversions
If the user selects *Aviation Units*:
\[
\begin{aligned}
\text{m} &\to \text{ft} = m \times 3.28084 \\
\text{m/s} &\to \text{kts} = m/s \times 1.94384 \\
\text{rad} &\to \text{deg} = rad \times \frac{180}{\pi}
\end{aligned}
\]

## Summary of Calculated Variables

| Variable | Description | Unit |
|-----------|--------------|------|
| **yaw_rad**, **pitch_rad**, **roll_rad** | Euler angles | rad |
| **north_m**, **east_m**, **down_m** | Local NED positions | m |
| **u_m_s**, **v_m_s**, **w_m_s** | Body velocities | m/s |
| **CL**, **CD**, **CY** | Aerodynamic coefficients | - |
| **Lift_N**, **Drag_N**, **SideForce_N** | Aerodynamic forces | N |
| **rho** | Air density | kg/(m²*m) |

## Requirements

MATLAB R2023a or newer version

## Author

Sedat ARSLAN
AI Engineer

## References

- MATLAB Global Functions Documentation - [https://www.mathworks.com](https://www.mathworks.com)
- MATLAB App Designer Documentation - [https://www.mathworks.com/help/matlab/app-designer.html](https://www.mathworks.com/help/matlab/app-designer.html)
- Example of Flight Log Analysis from Youtube & user forums
