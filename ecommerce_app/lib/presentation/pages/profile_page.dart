import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client_provider.dart';
import '../../core/theme/wishlist_heart_sizes.dart';
import '../../features/addresses/domain/entities/user_address.dart';
import '../../features/addresses/state/user_addresses_provider.dart';
import '../../features/auth/data/auth_error_mapper.dart';
import '../../features/auth/state/auth_actions_controller.dart';
import '../../features/auth/state/auth_session_provider.dart';
import '../../features/checkout/domain/shipping_details.dart';
import '../utils/main_shell_navigation.dart';
import '../utils/auth_issue_presenter.dart';
import '../utils/open_storefront_legal_page.dart';
import '../widgets/legal_support_links.dart';
import '../../core/config/storefront_legal_urls.dart';

class _ProfileSnapshot {
  final String fullName;
  final String phone;
  final String address;
  const _ProfileSnapshot({
    required this.fullName,
    required this.phone,
    required this.address,
  });
}

final _profileSnapshotProvider = FutureProvider.autoDispose<_ProfileSnapshot>((ref) async {
  final user = ref.watch(authSessionProvider).asData?.value;
  if (user == null) return const _ProfileSnapshot(fullName: '', phone: '', address: '');
  final client = ref.watch(supabaseClientProvider);
  try {
    final row = await client
        .from('profiles')
        .select('full_name, phone, address')
        .eq('id', user.id)
        .maybeSingle();
    return _ProfileSnapshot(
      fullName: (row?['full_name'] ?? user.fullName ?? '').toString(),
      phone: (row?['phone'] ?? '').toString(),
      address: (row?['address'] ?? '').toString(),
    );
  } catch (_) {
    return _ProfileSnapshot(fullName: user.fullName ?? '', phone: '', address: '');
  }
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.listenManual<Map<int, int>>(
      storefrontScrollToTopSignalProvider,
      (previous, next) {
        final prevSignal = previous?[StorefrontTab.account.shellIndex] ?? 0;
        final nextSignal = next[StorefrontTab.account.shellIndex] ?? 0;
        if (nextSignal == prevSignal) return;
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final profile = ref.watch(_profileSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: const Text(
          'Account',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }
            await openStorefrontTab(ref, context, StorefrontTab.home);
          },
        ),
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load account: $error')),
        data: (user) {
          if (user == null) return const Center(child: CircularProgressIndicator());
          return profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Failed to load profile: $error')),
            data: (snapshot) {
              final displayName = snapshot.fullName.trim().isNotEmpty
                  ? snapshot.fullName.trim()
                  : ((user.fullName ?? '').trim().isNotEmpty ? user.fullName!.trim() : 'User');
              final displayContact = snapshot.phone.trim().isNotEmpty
                  ? '+91 ${snapshot.phone.trim()}'
                  : user.email;

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_profileSnapshotProvider);
                  ref.invalidate(authSessionProvider);
                  ref.invalidate(userAddressesProvider);
                  await Future.wait([
                    ref.read(_profileSnapshotProvider.future),
                    ref.read(userAddressesProvider.future),
                  ]);
                },
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ProfileHeaderCard(
                      name: displayName,
                      contact: displayContact,
                      onEdit: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _EditProfilePage(
                              userId: user.id,
                              email: user.email,
                              initialName: displayName,
                              initialPhone: snapshot.phone,
                              initialAddress: snapshot.address,
                            ),
                          ),
                        );
                        ref.invalidate(_profileSnapshotProvider);
                        ref.invalidate(authSessionProvider);
                      },
                    ),
                    const SizedBox(height: 14),
                    const _Label('Customer details'),
                    _SingleMenuCard(
                      icon: Icons.badge_outlined,
                      title: 'Customer Details',
                      subtitle: 'View account details',
                      onTap: () => Navigator.of(context).pushNamed('/customer-details'),
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionBox(
                            icon: Icons.receipt_long_outlined,
                            title: 'My Orders',
                            subtitle: 'Track orders',
                            onTap: () => Navigator.of(context).pushNamed('/orders'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionBox(
                            icon: Icons.favorite_border,
                            iconSize: WishlistHeartSizes.profileQuickAction,
                            title: 'Wishlist',
                            subtitle: 'Saved items',
                            onTap: () => Navigator.of(context).pushNamed('/wishlist'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _Label('Legal & Support'),
                    const LegalSupportLinksCard(),
                    const SizedBox(height: 14),
                    const _Label('Account options'),
                    Card(
                      elevation: 1,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          _MenuRow(
                            icon: Icons.person_outline,
                            title: 'My Profile',
                            subtitle: 'Edit personal details',
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _EditProfilePage(
                                    userId: user.id,
                                    email: user.email,
                                    initialName: displayName,
                                    initialPhone: snapshot.phone,
                                    initialAddress: snapshot.address,
                                  ),
                                ),
                              );
                              ref.invalidate(_profileSnapshotProvider);
                            },
                          ),
                          _MenuRow(
                            icon: Icons.location_on_outlined,
                            title: 'Delivery Addresses',
                            subtitle: 'Manage saved addresses',
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => const _AddressesPage()),
                              );
                              ref.invalidate(userAddressesProvider);
                            },
                          ),
                        _MenuRow(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'Manage app preferences',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings page will be available soon.')),
                          ),
                        ),
                          _MenuRow(
                            icon: Icons.help_outline,
                            title: 'Help / Support',
                            subtitle: 'FAQs and contact',
                            onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.support),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.10),
                      foregroundColor: Colors.red.shade700,
                    ),
                    onPressed: () => _signOutWithFormalErrors(context, ref),
                    child: const Text('Logout'),
                  ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.contact,
    required this.onEdit,
  });

  final String name;
  final String contact;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    final avatarText = initials.isEmpty ? 'U' : initials;

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(radius: 24, child: Text(avatarText)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SingleMenuCard extends StatelessWidget {
  const _SingleMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _QuickActionBox extends StatelessWidget {
  const _QuickActionBox({
    required this.icon,
    this.iconSize = 20,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOrders = title.toLowerCase().contains('order');
    final accent = isOrders ? const Color(0xFF1E88E5) : const Color(0xFFE53935);
    final chipBg = accent.withOpacity(0.14);
    return Material(
      color: scheme.surface.withOpacity(0.42),
      elevation: 2,
      shadowColor: accent.withOpacity(0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accent.withOpacity(0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: iconSize, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _EditProfilePage extends ConsumerStatefulWidget {
  const _EditProfilePage({
    required this.userId,
    required this.email,
    required this.initialName,
    required this.initialPhone,
    required this.initialAddress,
  });

  final String userId;
  final String email;
  final String initialName;
  final String initialPhone;
  final String initialAddress;

  @override
  ConsumerState<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<_EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _addressCtrl = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final client = ref.read(supabaseClientProvider);
    try {
      try {
        await client
            .from('profiles')
            .update({
              'full_name': _nameCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
              'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
            })
            .eq('id', widget.userId);
      } catch (_) {
        await client
            .from('profiles')
            .update({'full_name': _nameCtrl.text.trim()})
            .eq('id', widget.userId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Name cannot be empty.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: widget.email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        helperText: 'Email is managed by authentication provider.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      validator: (value) => ShippingDetails.isValidIndianPhone((value ?? '').trim())
                          ? null
                          : 'Enter valid 10-digit phone.',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address (Optional)',
                        hintText: 'House/Flat, Street/Area',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? 'Saving...' : 'Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressesPage extends ConsumerWidget {
  const _AddressesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(userAddressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Addresses')),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load addresses: $error')),
        data: (list) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Saved Addresses',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No saved addresses yet.'),
                  ),
                )
              else
                ...list.map((address) => _AddressCard(address: address)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const _AddressFormPage()),
                  );
                  ref.invalidate(userAddressesProvider);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New Address'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address});
  final UserAddress address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(address.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                    ),
                    child: const Text('Default'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(address.phone),
            const SizedBox(height: 4),
            Text(_formatAddress(address)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => _AddressFormPage(initial: address)),
                    );
                    ref.invalidate(userAddressesProvider);
                  },
                  child: const Text('Edit'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete address?'),
                            content: Text('Remove address for ${address.fullName}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (!ok) return;
                    await ref.read(userAddressRepositoryProvider).deleteAddress(address.id);
                    if (!context.mounted) return;
                    ref.invalidate(userAddressesProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address deleted.')),
                    );
                  },
                  child: const Text('Delete'),
                ),
                if (!address.isDefault)
                  FilledButton.tonal(
                    onPressed: () async {
                      await ref.read(userAddressRepositoryProvider).setDefaultAddress(address.id);
                      if (!context.mounted) return;
                      ref.invalidate(userAddressesProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Default address updated.')),
                      );
                    },
                    child: const Text('Set as Default'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressFormPage extends ConsumerStatefulWidget {
  const _AddressFormPage({this.initial});
  final UserAddress? initial;

  @override
  ConsumerState<_AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends ConsumerState<_AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _line1Ctrl;
  late final TextEditingController _line2Ctrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _postalCtrl;
  late final TextEditingController _countryCtrl;
  bool _isDefault = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final address = widget.initial;
    _nameCtrl = TextEditingController(text: address?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: address?.phone ?? '');
    _line1Ctrl = TextEditingController(text: address?.addressLine ?? '');
    _line2Ctrl = TextEditingController(text: address?.addressLine2 ?? '');
    _cityCtrl = TextEditingController(text: address?.city ?? '');
    _stateCtrl = TextEditingController(text: address?.state ?? '');
    _postalCtrl = TextEditingController(text: address?.postalCode ?? '');
    _countryCtrl = TextEditingController(text: address?.country ?? 'India');
    _isDefault = address?.isDefault ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final repo = ref.read(userAddressRepositoryProvider);
    try {
      if (widget.initial == null) {
        await repo.createAddress(
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          addressLine: _line1Ctrl.text.trim(),
          addressLine2: _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
          city: _cityCtrl.text.trim(),
          state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
          postalCode: _postalCtrl.text.trim(),
          country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
          isDefault: _isDefault,
        );
      } else {
        await repo.updateAddress(
          id: widget.initial!.id,
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          addressLine: _line1Ctrl.text.trim(),
          addressLine2: _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
          city: _cityCtrl.text.trim(),
          state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
          postalCode: _postalCtrl.text.trim(),
          country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
          isDefault: _isDefault,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initial == null
              ? 'Address added successfully.'
              : 'Address updated successfully.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save address: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Add Address' : 'Edit Address')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Full name is required.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      validator: (value) => ShippingDetails.isValidIndianPhone((value ?? '').trim())
                          ? null
                          : 'Enter valid 10-digit phone.',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _line1Ctrl,
                      decoration: const InputDecoration(labelText: 'Address Line 1'),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Address line 1 is required.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _line2Ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Address Line 2 (Landmark / Store / Building)',
                      ),
                      validator: (value) => (value ?? '').trim().length < 3
                          ? 'Address line 2 is required for delivery'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'City is required.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _stateCtrl,
                      decoration: const InputDecoration(labelText: 'State'),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'State is required.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _postalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Postal Code'),
                      validator: (value) => ShippingDetails.isValidIndianPostal((value ?? '').trim())
                          ? null
                          : 'Enter valid 6-digit postal code.',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _countryCtrl,
                      decoration: const InputDecoration(labelText: 'Country'),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Country is required.' : null,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _isDefault,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _isDefault = value),
                      title: const Text('Set as Default'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? 'Saving...' : 'Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAddress(UserAddress a) {
  final parts = <String>[
    a.addressLine,
    if ((a.addressLine2 ?? '').trim().isNotEmpty) a.addressLine2!.trim(),
    a.city,
    if ((a.state ?? '').trim().isNotEmpty) a.state!.trim(),
    a.postalCode,
    if ((a.country ?? '').trim().isNotEmpty) a.country!.trim(),
  ];
  return parts.where((part) => part.trim().isNotEmpty).join(', ');
}

Future<void> _signOutWithFormalErrors(BuildContext context, WidgetRef ref) async {
  final confirm = await _confirmLogout(context);
  if (!confirm || !context.mounted) return;

  Future<void> attempt() async {
    try {
      await ref.read(authActionsProvider.notifier).signOut();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have been signed out successfully.')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (error) {
      if (!context.mounted) return;
      await presentAuthIssue(
        context,
        flow: AuthIssueFlow.signOut,
        error: resolvePresentableAuthError(error, isSignUp: false),
        onRetry: attempt,
      );
    }
  }

  await attempt();
}

Future<bool> _confirmLogout(BuildContext context) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Logout?'),
      content: const Text('Do you really want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  return shouldLogout ?? false;
}
