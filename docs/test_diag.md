::: {layout-ncol=1}

flowchart TD A\[Simulate Farm Locations and Populations\] –\>
B\[Simulate Outbreak Source Farm\] B –\> C\[Simulate Airborne Plume
Dispersion with HYSPLIT\] C –\> D\[Aggregate Particle Trajectories to
Concentration Grids\] D –\> E\[Optional: Convert to Mass
Concentrations\] D –\> F\[Extract Concentrations at Farm Locations\] F
–\> G\[Model Probability of Particle Introduction\] G –\> H\[Identify
Farms with Highest Risk\]
