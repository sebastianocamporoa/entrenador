import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Para cerrar sesión

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  Package? _monthlyPackage;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  // 1. Traer el "Menú" de precios desde RevenueCat
  Future<void> _fetchOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();

      // Buscamos la oferta actual y el paquete mensual
      if (offerings.current != null && offerings.current!.monthly != null) {
        setState(() {
          _monthlyPackage = offerings.current!.monthly;
        });
      }
    } catch (e) {
      debugPrint("Error trayendo precios: $e");
    }
  }

  // 2. Ejecutar la compra
  Future<void> _purchase() async {
    if (_monthlyPackage == null) return;

    setState(() => _isLoading = true);

    try {
      // CORRECCIÓN: Usamos 'var' porque la librería ahora devuelve un 'PurchaseResult'
      var result = await Purchases.purchasePackage(_monthlyPackage!);

      // Extraemos la información del cliente desde el resultado
      // (Nota: Si 'customerInfo' te marca error, prueba con 'result.purchaserInfo')
      CustomerInfo customerInfo = result.customerInfo;

      // Verificamos si la compra desbloqueó el acceso
      if (customerInfo.entitlements.all["pro_access"]?.isActive == true) {
        // ¡ÉXITO! Navegar al Home
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } catch (e) {
      debugPrint("Error en compra: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Acceso Profesional",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Para gestionar clientes ilimitados, necesitas una suscripción activa.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Spacer(),

              // Tarjeta de Precio
              if (_monthlyPackage != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Plan Mensual",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _monthlyPackage!
                            .storeProduct
                            .priceString, // Muestra "$100.000" automático
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const CircularProgressIndicator(),

              const SizedBox(height: 20),

              // Botón de Suscribirse
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading || _monthlyPackage == null
                      ? null
                      : _purchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SUSCRIBIRSE AHORA"),
                ),
              ),

              const SizedBox(height: 20),

              // Botón de Cerrar Sesión (Salida de emergencia)
              TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  // Redirigir al Login...
                },
                child: const Text(
                  "Cerrar sesión",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const Spacer(),
              const Text(
                "Términos de uso • Política de Privacidad",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
