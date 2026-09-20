# 🗺️ Realistic Harvesting — Development Roadmap

> **Help shape the future of Realistic Harvesting!**
> Submit your ideas, feedback, and feature requests on [GitHub Issues](https://github.com/exekx/FS25_RealisticHarvesting/issues).

---

## 🌟 Vision & Goal
Realistic Harvesting transforms combine harvesters in Farming Simulator 25 into living, breathing agricultural machines. Through physics-based engine load modeling, authentic throughput limits, equipment degradation, calibration systems, and detailed telemetry, our goal is to deliver the ultimate harvester simulation experience.

---

## ✅ Completed Milestones

The following features have been successfully designed, implemented, and released:

*   [x] **Physics-Based Dynamic Engine Load Engine:** Real-time power balance modeling ($P_{total} = P_{base} + P_{header}(v) + P_{process} + P_{soil}$) replacing artificial scripted caps.
*   [x] **Dynamic Hydrostatic Speed Limiter:** Smooth exponential speed controller preventing drum stall while maintaining optimal equilibrium harvesting speeds.
*   [x] **Physical & Visual Crop Loss System:** Exponential crop loss penalties that physically deduct grain from the hopper upon severe overload or improper settings.
*   [x] **Interactive In-Cab Calibration Terminal (Shift + K):** Modern touchscreen terminal for real-time adjustments of fan speed, rotor RPM, concave clearance, and sieves with dynamic map crop extraction.
*   [x] **4-Tier Electronics Progression:** Shop-configurable upgrade packages from basic Manual Combine to Sensors, Telemetry Monitor, and Opti-Harvest AI.
*   [x] **Multi-Tier AI Worker & Courseplay Auto-Tuning:** Dynamic field speed and calibration tuning for AI helpers without game freezes.
*   [x] **Swathing & Pickup Header Integration:** Full support for pickup headers with realistic reduced cutting resistance ($0.75\times$ load factor).
*   [x] **Full Harvester Category Coverage:** Dedicated physical processing models for Grain, Forage, Root Crops (potatoes, beets, carrots, parsnips, vegetables), Cotton, and Sugarcane.
*   [x] **Viticulture & Orchard System (Grapes & Olives):** Full support for self-propelled straddle harvesters (New Holland Braud, Grégoire) with 3-parameter viticulture controls (Shaker rods, Bucket conveyor, Extractor fans) and integrated shaker tunnel physics.
*   [x] **Mechanical Equipment Wear Loss System:** Realistic yield penalties and header drag modeling from blunt cutterbar knives and worn thresher rasp bars with zero double-deduction.
*   [x] **Smart Cabin Overload Buzzer & Acoustic Balancing:** 3-pulse alert pattern with 18-second reminder pause and uniform volume inside and outside the cab.
*   [x] **Dedicated Public Integration API (`RHM_Api.lua`):** Safe, zero-friction read-only telemetry API for third-party mods (ADS, Courseplay, AutoDrive, EnhancedVehicle, dashboards).
*   [x] **Full Multiplayer & Dedicated Server Synchronization:** Server-authoritative physics, dirty flag bitmasks, and persistent client/server XML configs.
*   [x] **Universal 15-Language Localization:** Native translation strings for all supported languages.

---

## 🚀 Active & Future Development Milestones

Based on community feedback and core realism targets, the following major systems are planned:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           UPCOMING MILESTONES                               │
├───────────────────────────────┬─────────────────────────────────────────────┤
│ 1. Harvest History & Trip UI  │ Field trip odometer, loss causes, seasons   │
│ 2. Machine Types & Dynamics   │ Walker vs Single-Rotor vs Twin-Rotor/Hybrid │
│ 3. Feeder Clogging System     │ Slip clutch, reverse feed, hard blockage    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Milestone 1: Harvest History & Field Analytics Terminal (Trip Computer)
*A dedicated statistical terminal inspired by modern combine monitors (e.g. John Deere Operations Center, Claas TELEMATICS, Case IH AFS Connect, ADS / MoistureSystem interfaces).*

*   **Dedicated Analytics GUI Window:**
    *   Accessible via hotkey or in-game tablet tab.
    *   Clean, modern dashboard displaying comprehensive harvest records.
*   **Active Fleet Overview:**
    *   List of all harvesters currently or previously operated on the farm.
    *   Total operating hours under load, total hectares harvested, and lifetime throughput.
*   **Crop-Specific Breakdown:**
    *   Volume harvested (liters, bushels, metric tons) broken down by crop type.
    *   Average field yield ($t/ha$, $bu/ac$) and average harvesting speed ($km/h$).
*   **Transparent Loss Cause Breakdown:**
    *   Detailed accounting of lost yield with exact causal attribution:
        *   **Throughput & Speed Overload Loss** (driving too fast for crop density).
        *   **Calibration & Settings Loss** (suboptimal fan, concave, or sieve adjustments).
        *   **Moisture & Dew Loss** (harvesting during high moisture conditions).
        *   **Mechanical Wear Loss** (blunt knife sections and worn rasp bars).
*   **Field & Seasonal Trip Computer (Resettable Odometer):**
    *   Operates like a trip meter in a modern car.
    *   **"Reset Field Trip" button**: Operator resets the trip meter when entering a new field.
    *   Instantly tracks: Field Area ($ha$), Harvested Mass ($t$), Fuel Used ($L$), Average Load (%), Total Losses ($t$ and %), and Total Harvesting Time.
    *   Allows comparing operator efficiency across different fields and seasons.

---

### Milestone 2: Harvester Architecture & Model-Specific Dynamics
*Differentiating combine performance based on physical threshing architecture and manufacturer systems.*

*   **Threshing System Architecture Classes:**
    *   **Conventional Straw Walkers (Клавішні соломотряси):**
        *   *Examples:* Claas Tucano/Trion Walker, John Deere T-Series, Deutz-Fahr C-Series.
        *   *Characteristics:* Gentle on straw, lower power requirement on dry crop, highly sensitive to hilly terrain and massive straw volume.
    *   **Single Axial Rotor (Однороторні):**
        *   *Examples:* Case IH Axial-Flow, John Deere S-Series, New Holland CR Single.
        *   *Characteristics:* Superb grain quality and high capacity on dry corn, sunflowers, and cereals; higher power drag and plugging risk in wet, green straw.
    *   **Twin-Rotor & Hybrid Systems (Двороторні та Гібридні APS):**
        *   *Examples:* Claas Lexion APS Synflow Hybrid, New Holland CR Twin Rotor, Fendt IDEAL.
        *   *Characteristics:* Extreme throughput capacity and high separation force under damp conditions; higher base fuel consumption and engine power requirements.
*   **Model-Specific Tuning & Brand Profiles:**
    *   Individual moisture tolerance and crop flow curves tailored to real-world machine specs.
    *   Slope sensitivity modeling: combines without 3D/4D sieve leveling suffer higher sieve losses on steep slopes.

---

### Milestone 3: Feederhouse & Drum Clogging System (Verstopfung)
*Fully integrated, interactive header and threshing drum plugging mechanics when severely overworking equipment.*

*   **Physical Clogging Accumulation:**
    *   Operating deep in the red zone ($>105\text{--}115\%$ load), slug feeding from uneven windrows, or hitting heavy damp patches progressively builds feederhouse blockage ($0\text{--}100\%$).
*   **Slip Clutch Warning (Пробуксовка запобіжної муфти):**
    *   Feeder slip clutch ratchets when torque exceeds safe thresholds, producing authentic mechanical acoustic chatter (`slipClutch` sound).
    *   Cutterbar and reel stop spinning while the engine continues to run.
*   **Hydraulic Feederhouse Reversing (Реверс похилої камери):**
    *   Operator stops the machine, shifts to reverse feed (holding reverse key), and slowly expels the plugged crop wad back onto the header table or ground.
    *   Reversed crop is deposited onto the ground as a pickable swath.
*   **Hard Blockage & Manual Clear On-Foot:**
    *   Premature restart under heavy residual plug ($>30\%$) or severe sudden stall triggers a mechanical hard lock.
    *   Requires the operator to dismount, walk to the front of the cutterbar/pickup, and manually clear the obstruction with a clearing tool before restarting.
*   **AI Safety & Automation:**
    *   AI helpers and Courseplay dynamically regulate speed to prevent plugging, with full configurable safety exemptions.

---

*Note: This roadmap reflects active development priorities and may be adjusted based on community feedback, technical feasibility, and GIANTS Engine updates.*
