import 'design_registry.dart';
import 'designs/artisan_craft_design.dart';
import 'designs/vanguard_immersive_design.dart';
import 'designs/le_jardin_design.dart';
import 'designs/ethos_minimal_design.dart';
import 'designs/velvet_night_design.dart';
import 'designs/serenity_design.dart';
import 'designs/clean_standard_design.dart';
import 'designs/neon_pulse_design.dart';

/// Registers all premium storefront designs into the DesignRegistry.
/// Old standard designs have been replaced by these immersive masterpieces.
void registerAllDesigns() {
  DesignRegistry.register(ArtisanCraftDesign());
  DesignRegistry.register(VanguardImmersiveDesign());
  DesignRegistry.register(LeJardinDesign());
  DesignRegistry.register(EthosMinimalDesign());
  DesignRegistry.register(VelvetNightDesign());
  DesignRegistry.register(SerenityDesign());
  DesignRegistry.register(CleanStandardDesign());
  DesignRegistry.register(NeonPulseDesign());
}
