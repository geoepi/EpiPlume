
## **Workflow Summary**

### **Main Goals**

Analysis objectives:

1. Model the epidemiological dynamics of a poultry flock infected by an airborne pathogen, focusing on environmental shedding.
    
2. Evaluate the potential for airborne transmission to other poultry houses and the broader landscape.
    
3. Quantify spatiotemporal dispersion patterns and identify areas potentially exposed to infectious particles.
    
4. Utilize statistical models to estimate pathogen distribution, to aid in guiding management decisions.
    

---

### **Step-by-Step Workflow**

### **Step 1: Defining the Study Domain**

The first critical step establishes the geographic context.

- **Purpose:**
    
    - Define a spatial domain centered around a known or hypothetical emission source.
        
    - Simulate poultry farm distributions to represent the at-risk populations.
        
- **Code Actions:**
    
    - **Raster Grid Creation:** Established using geographic coordinates (-89.031407, 32.494830), extending 30 km² with a resolution of 250 meters.
        
    - **Farm Simulation:** Random generation of 20 poultry farm locations based on chicken density data to realistically represent vulnerable populations.
        
- **Parameters to Justify:**
    
    - **Domain extent and resolution:** Must consider realistic dispersal distances (?) and precision for the pathogen, AND model computational constraints.
        
    - **Farm simulation (number and density):** Should align with actual poultry farm densities in the region (?).
        

---

### **Step 2: SEIR Epidemiological Dynamics**

This component simulates virus dynamics within an infected poultry house using a compartmental SEIRv model.

- **Purpose:**
    
    - Characterize the internal epidemiological dynamics (Susceptible, Exposed, Infectious, Recovered) of the poultry population.
        
    - Approximate environmental shedding virus (per bird), determining the total amount of virus emitted into the air.
        
- **Code Actions:**
    
    - Hourly simulation of flock infection over a 30-day period (?).
        
    - Tracking environmental virus concentration based on poultry infection status, house ventilation, and virus viability (decay/halflife).
        
- **Parameters to Justify:**
    
    - **Epidemiological rates (beta, sigma, gamma):** Derived from literature or experimental data.
        
    - **Virus shedding rate (qV):** Must reflect realistic shedding rates (experimental studies?).
        
    - **Ventilation rate (Q):** Based on poultry house characteristics (dimensions and ventilation); determines airborne virus emission rates.
        
    - **Virus viability and viability threshold:** Virus survival outside of hosts, affects environmental persistence (aerosol vs. praticle).
        

---

### **Step 3: Atmospheric Dispersion Modeling (Plume Dispersion and Trajectories)**

Physical atmospheric dispersion models to approximate where emitted particles could disperse spatially and temporally.

#### **Plume Dispersion**

- **Purpose:**
    
    - Estimate the forward-looking spatial distribution of individual particles post-emission.
        
    - Supports quantitative estimates of particle concentrations.
        
- **Code Actions:**
    
    - Simulated emissions for defined time intervals, cuurently using climate reanalysis meteorological data (what data provides the best resolution and precision?)).
        
- **Parameters to Justify:**
    
    - **Emission height and rate:** Must match the realistic heights and intensities at which virus-laden particles leave poultry facilities.
        
    - **Particle characteristics (diameter, density, shape factor):** Govern aerodynamic behavior; ideally sourced from barn experimental studies.
        
    - **Time windows (release and dispersion dates):** Should reflect plausible outbreak scenarios or critical management periods.
        

#### **Trajectory Modeling**

- **Purpose:**
    
    - Conduct backward trajectory analyses to determine/compare potential source locations retrospectively; do these alinge with observed of modeled (SEIR) timelines?.
        
- **Code Actions:**
    
    - Backward trajectory simulations from the receptor (secondary outbreak) over daily intervals at specified times (curently hours 0, 6, 12, 18).
        
- **Parameters to Justify:**
    
    - **Trajectory duration (6 hours) and vertical extent (5000 m):** Limited vaiability of virus, standard should be distance based maybe...
        
    - **Emission frequency and timing:** Should reflect typical diurnal variations in farm emissions or meteorological patterns.
        

---

### **Step 4: Converting Particle Counts to Concentrations**

Quantify airborne particle distributions and translate to biologically relevant metrics.

- **Purpose:**
    
    - Produce spatially explicit maps of particle concentration, providing input for risk assessment or exposure assessment.
        
- **Code Actions:**
    
    - Conversion of raw particle counts into volumetric particle concentration (particles/m³).
        
    - Optional conversion into mass concentration metrics (µg/m³ or g/m³).
        
- **Parameters to Justify:**
    
    - **Voxel volume (height):** Chosen height (100 m); potentially dilutes particle concentration estimates.
        
    - **Particle mass properties:** Diameter, density, shape factor significantly influence particle settling and deposition.
        

---

### **Step 5: Spatiotemporal Modeling**

Integrates spatial dispersion predictions with temporal dynamics, quantify uncertainty and improve inference about spatial and temporal exposure risk.

- **Purpose:**
    
    - Estimates exposure risk by accounting for spatial-temporal correlation structures.
        
- **Code Actions:**
    
    - Joint modeling, combining binomial and gamma distributions to represent particle presence and intensity respectively.
        
    - Accounting for spatiotemporal dependencies and correlation structures.
        
- **Parameters to Justify:**
    
    - **Choice of priors:** Needed for stable model runsn and valid uncertainty quantification; must reflect expert opinion, exploratory analyses, or prior studies.
        
    - **Model complexity (AR1 temporal correlations, Gaussian priors):** Must balance between adequate representation and computational realism.
    
