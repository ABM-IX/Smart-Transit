import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/route_model.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../driver/driver_dashboard.dart';
import 'login_screen.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Selected mode: COMBI, BUS, TAXI
  String _selectedMode = 'COMBI';

  // Available and selected route
  List<TransitRoute> _availableRoutes = [];
  TransitRoute? _selectedRoute;
  bool _isLoadingRoutes = false;
  bool _createNewRoute = true;

  // Controllers
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final TextEditingController _fareController = TextEditingController(text: '8.00');

  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: '+267 ');
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRoutesForMode(_selectedMode);
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _originController.dispose();
    _destController.dispose();
    _fareController.dispose();
    _plateController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutesForMode(String mode) async {
    if (mode == 'TAXI') {
      setState(() {
        _availableRoutes = [];
        _selectedRoute = null;
        _createNewRoute = false;
      });
      return;
    }

    setState(() {
      _isLoadingRoutes = true;
      _fareController.text = mode == 'BUS' ? '35.00' : '8.00';
    });

    try {
      final routes = await _apiService.fetchRoutes(routeType: mode, onlyWithRegisteredDrivers: true);
      if (mounted) {
        setState(() {
          _availableRoutes = routes;
          if (routes.isNotEmpty) {
            _selectedRoute = routes.first;
            _createNewRoute = false;
          } else {
            _selectedRoute = null;
            _createNewRoute = true;
          }
          _isLoadingRoutes = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
          _createNewRoute = true;
        });
      }
    }
  }

  void _onModeChanged(String newMode) {
    setState(() {
      _selectedMode = newMode;
      _selectedRoute = null;
    });
    _loadRoutesForMode(newMode);
  }

  Future<void> _handleDriverRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMode != 'TAXI' && !_createNewRoute && _selectedRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an operating corridor or enter your route details.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = AuthService();
      String routeId;

      if (_selectedMode == 'TAXI') {
        routeId = 'taxi-dispatch';
      } else if (_createNewRoute || _selectedRoute == null) {
        final fare = double.tryParse(_fareController.text.trim()) ?? (_selectedMode == 'BUS' ? 35.0 : 8.0);
        routeId = await authService.createOrGetRoute(
          name: _routeNameController.text.trim(),
          originName: _originController.text.trim(),
          destinationName: _destController.text.trim(),
          routeType: _selectedMode,
          baseFare: fare,
        );
      } else {
        routeId = _selectedRoute!.id;
      }

      final plate = _plateController.text.trim().toUpperCase();

      final response = await authService.signUpDriver(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        serviceType: _selectedMode,
        vehiclePlate: plate,
        assignedRouteId: routeId,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      UserRole targetRole;
      if (_selectedMode == 'BUS') {
        targetRole = UserRole.driverBus;
      } else if (_selectedMode == 'TAXI') {
        targetRole = UserRole.driverTaxi;
      } else {
        targetRole = UserRole.driverCombi;
      }

      // Check if immediate active session
      if (response.session != null && response.user != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final transitProvider = Provider.of<TransitProvider>(context, listen: false);

        await authProvider.loadProfile(response.user!.id);
        if (!mounted) return;

        authProvider.updateDriverConfig(
          serviceType: _selectedMode,
          routeId: routeId,
          vehiclePlate: plate,
        );

        transitProvider.connectSocket(
          role: 'drivers',
          userId: response.user!.id,
          routeId: routeId,
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => DriverDashboard(initialRole: targetRole)),
          (route) => false,
        );
        return;
      }

      if (!mounted) return;

      // Email confirmation / prompt dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified, color: AppTheme.accentGreen, size: 28),
              SizedBox(width: 10),
              Text('Driver Registered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${_nameController.text.trim()}!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.black),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your transit operator profile for vehicle $plate ($_selectedMode) has been saved.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.darkGrey, height: 1.4),
                ),
                if (_selectedMode != 'TAXI') ...[
                  const SizedBox(height: 6),
                  Text(
                    'Assigned Corridor: ${_createNewRoute ? _routeNameController.text.trim() : (_selectedRoute?.name ?? routeId)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.black),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.offWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.lightGrey),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppTheme.midGrey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This corridor is now active and visible to passengers! You can sign in to begin your shift.',
                          style: TextStyle(fontSize: 11, color: AppTheme.midGrey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Proceed to Sign In'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TRANSIT OPERATOR REGISTRATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Driver Onboarding',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Register your vehicle and route. Once registered, your corridor is instantly active and visible to commuters.',
                  style: TextStyle(fontSize: 14, color: AppTheme.midGrey, height: 1.4),
                ),
                const SizedBox(height: 28),

                // Section 1: Transport Mode
                _buildSectionHeader('1. Select Transport Mode'),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeCard(
                        mode: 'COMBI',
                        title: 'Combi',
                        icon: Icons.airport_shuttle_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeCard(
                        mode: 'BUS',
                        title: 'Bus',
                        icon: Icons.directions_bus_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeCard(
                        mode: 'TAXI',
                        title: 'Taxi',
                        icon: Icons.local_taxi_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section 2: Route & Vehicle Assignment
                _buildSectionHeader('2. Vehicle & Route Assignment'),

                if (_selectedMode != 'TAXI') ...[
                  if (_isLoadingRoutes)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Checking registered corridors...', style: TextStyle(fontSize: 12, color: AppTheme.midGrey)),
                        ],
                      ),
                    ),
                  // Toggle between existing route or creating new route
                  if (_availableRoutes.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Join Existing Corridor')),
                            selected: !_createNewRoute,
                            selectedColor: AppTheme.black,
                            backgroundColor: AppTheme.offWhite,
                            labelStyle: TextStyle(
                              color: !_createNewRoute ? AppTheme.white : AppTheme.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (val) => setState(() => _createNewRoute = !val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('+ Add New Corridor')),
                            selected: _createNewRoute,
                            selectedColor: AppTheme.black,
                            backgroundColor: AppTheme.offWhite,
                            labelStyle: TextStyle(
                              color: _createNewRoute ? AppTheme.white : AppTheme.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (val) => setState(() => _createNewRoute = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (!_createNewRoute && _availableRoutes.isNotEmpty) ...[
                    const Text(
                      'Select Existing Corridor',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.black),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.offWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.lightGrey),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TransitRoute>(
                          isExpanded: true,
                          value: _selectedRoute,
                          items: _availableRoutes.map((route) {
                            return DropdownMenuItem<TransitRoute>(
                              value: route,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    route.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.black),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${route.originName} → ${route.destinationName} (P${route.baseFare.toStringAsFixed(2)})',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (route) => setState(() => _selectedRoute = route),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // New Corridor Definition
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.offWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.lightGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selectedMode == 'BUS' ? Icons.directions_bus : Icons.airport_shuttle,
                                size: 18,
                                color: AppTheme.black,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Register Operating Corridor ($_selectedMode)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _routeNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _buildInputDecoration(
                              label: 'Route Name / Identifier',
                              hint: 'e.g. Route 6 or Broadhurst to Station',
                              icon: Icons.alt_route,
                            ),
                            validator: (val) {
                              if (_selectedMode != 'TAXI' && _createNewRoute && (val == null || val.trim().isEmpty)) {
                                return 'Please enter your route name or number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _originController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _buildInputDecoration(
                                    label: 'Origin (Start)',
                                    hint: 'e.g. Broadhurst',
                                    icon: Icons.trip_origin,
                                  ),
                                  validator: (val) {
                                    if (_selectedMode != 'TAXI' && _createNewRoute && (val == null || val.trim().isEmpty)) {
                                      return 'Enter start point';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _destController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _buildInputDecoration(
                                    label: 'Destination (End)',
                                    hint: 'e.g. Bus Rank',
                                    icon: Icons.location_on,
                                  ),
                                  validator: (val) {
                                    if (_selectedMode != 'TAXI' && _createNewRoute && (val == null || val.trim().isEmpty)) {
                                      return 'Enter end point';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _fareController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'Standard Fare (BWP)',
                              hint: '8.00',
                              icon: Icons.payments_outlined,
                            ),
                            validator: (val) {
                              if (_selectedMode != 'TAXI' && _createNewRoute) {
                                if (val == null || double.tryParse(val) == null) {
                                  return 'Enter valid fare amount';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.offWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.lightGrey),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.near_me, color: AppTheme.accentGreen, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Taxi cabs operate on dynamic metropolitan dispatch across Gaborone and surrounding areas.',
                            style: TextStyle(fontSize: 12, color: AppTheme.darkGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Vehicle Number Plate
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _buildInputDecoration(
                    label: 'Vehicle Plate Number',
                    hint: 'e.g. B-123-BW or B 492 ABC',
                    icon: Icons.confirmation_number_outlined,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your vehicle registration plate';
                    }
                    if (val.trim().length < 4) {
                      return 'Please enter a valid Botswana plate number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Section 3: Driver Credentials
                _buildSectionHeader('3. Driver Credentials & Contact'),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _buildInputDecoration(
                    label: 'Full Name',
                    hint: 'e.g. Tuelo Kgosi',
                    icon: Icons.person_outline,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration(
                    label: 'Driver Phone Number',
                    hint: '+267 72 987 654',
                    icon: Icons.phone_android_outlined,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 8) {
                      return 'Please enter a valid phone number for dispatch';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _buildInputDecoration(
                    label: 'Email Address',
                    hint: 'driver@smarttransit.bw',
                    icon: Icons.email_outlined,
                  ),
                  validator: (val) {
                    if (val == null || !val.contains('@') || !val.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _buildInputDecoration(
                    label: 'Password',
                    hint: 'Minimum 6 characters',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.midGrey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _buildInputDecoration(
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.midGrey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleDriverRegister,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Register Driver Profile'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign In link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already registered? ', style: TextStyle(color: AppTheme.midGrey)),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: AppTheme.black,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.black),
      ),
    );
  }

  Widget _buildModeCard({
    required String mode,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      onTap: () => _onModeChanged(mode),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.black : AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.black : AppTheme.lightGrey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.white : AppTheme.black,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? AppTheme.white : AppTheme.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.midGrey),
      prefixIcon: Icon(icon, color: AppTheme.black),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.offWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.lightGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.lightGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.black, width: 1.5),
      ),
    );
  }
}
