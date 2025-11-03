class ServiceCategory {
  final String id;
  final String nombre;
  final String icon;
  final List<String> serviciosSugeridos;

  const ServiceCategory({
    required this.id,
    required this.nombre,
    required this.icon,
    required this.serviciosSugeridos,
  });

  static const List<ServiceCategory> predefinidas = [
    ServiceCategory(
      id: 'corte',
      nombre: 'Cortes',
      icon: '✂️',
      serviciosSugeridos: [
        'Corte de Dama',
        'Corte de Caballero',
        'Corte de Niño',
        'Peinado',
      ],
    ),
    ServiceCategory(
      id: 'coloracion',
      nombre: 'Coloración',
      icon: '🎨',
      serviciosSugeridos: [
        'Tinte Completo',
        'Mechas',
        'Balayage',
        'Ombré',
      ],
    ),
    ServiceCategory(
      id: 'tratamientos',
      nombre: 'Tratamientos',
      icon: '💆',
      serviciosSugeridos: [
        'Tratamiento Capilar',
        'Keratina',
        'Botox Capilar',
        'Hidratación',
      ],
    ),
    ServiceCategory(
      id: 'unas',
      nombre: 'Uñas',
      icon: '💅',
      serviciosSugeridos: [
        'Manicura',
        'Pedicura',
        'Uñas Acrílicas',
        'Uñas de Gel',
      ],
    ),
    ServiceCategory(
      id: 'facial',
      nombre: 'Faciales',
      icon: '🧖',
      serviciosSugeridos: [
        'Limpieza Facial',
        'Mascarilla',
        'Exfoliación',
        'Masaje Facial',
      ],
    ),
    ServiceCategory(
      id: 'maquillaje',
      nombre: 'Maquillaje',
      icon: '💄',
      serviciosSugeridos: [
        'Maquillaje Social',
        'Maquillaje de Novia',
        'Maquillaje Profesional',
        'Cejas y Pestañas',
      ],
    ),
    ServiceCategory(
      id: 'masajes',
      nombre: 'Masajes',
      icon: '🙌',
      serviciosSugeridos: [
        'Masaje Relajante',
        'Masaje Terapéutico',
        'Masaje con Piedras',
        'Masaje Descontracturante',
      ],
    ),
    ServiceCategory(
      id: 'depilacion',
      nombre: 'Depilación',
      icon: '✨',
      serviciosSugeridos: [
        'Depilación con Cera',
        'Depilación Láser',
        'Depilación Facial',
        'Depilación Corporal',
      ],
    ),
  ];

  static ServiceCategory? findById(String id) {
    try {
      return predefinidas.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }
}
