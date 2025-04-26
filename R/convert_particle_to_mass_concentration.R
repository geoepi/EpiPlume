convert_particle_to_mass_concentration <- function(
    concentration_particles_m3, # input particle density
    pdiam_um = cfg$plume$pdiam, # particle diameter in micrometers (um)
    density_g_cm3 = cfg$plume$density,     # particle density in g/cm3
    shape_factor = cfg$plume$shape_factor,      # shape factor (0=rough, 1=smooth sphere)
    output_units = "ug/m3"   # "ug/m3" or "g/m3"
) {
  # diameter to radius (meters)
  r_m <- (pdiam_um / 2) * 1e-6  # micrometers to meters
  
  # volume of a sphere (m3)
  V_sphere_m3 <- (4/3) * pi * r_m^3
  
  # shape factor
  V_particle_m3 <- V_sphere_m3 * shape_factor
  
  # density to g/m3
  density_g_m3 <- density_g_cm3 * 1e6  # g/cm3 to g/m3
  
  # mass per particle (g/particle)
  mass_particle_g <- V_particle_m3 * density_g_m3
  
  # particle concentration to mass concentration
  mass_concentration_g_m3 <- concentration_particles_m3 * mass_particle_g
  
  # units
  if (output_units == "ug/m3") {
    mass_concentration <- mass_concentration_g_m3 * 1e6  # g to ug
  } else if (output_units == "g/m3") {
    mass_concentration <- mass_concentration_g_m3
  } else {
    stop("We going with 'g/m3' or 'ug/m3'?")
  }
  
  return(mass_concentration)
}
