# Guía de Rediseño Beauteek - Tema Oscuro

## 🎨 Paleta de Colores

```dart
- Fondo principal: #1C1C1E (oscuro)
- Fondo de tarjetas: #2C2C2E (gris oscuro)
- Naranja primario: #FF9500
- Texto primario: #FFFFFF (blanco)
- Texto secundario: #AAAAAA (gris claro)
- Divisores: #3A3A3C
```

## 📋 Páginas a Rediseñar

### 1. LOGIN SCREEN (`login_screen.dart`)
**Cambios principales:**
- Fondo oscuro (#1C1C1E)
- Logo circular naranja en la parte superior
- Título "Beauteek" blanco y bold
- Campos de texto con fondo #2C2C2E
- Botón naranja (#FF9500) redondeado
- Botones de redes sociales circulares en fila
- Link "Olvidé mi contraseña" en naranja

### 2. REGISTER SCREEN (`register_screen.dart`)
**Cambios principales:**
- Mismo estilo que login
- AppBar con flecha atrás blanca
- Título "Crear Cuenta" centrado
- Campos: nombre completo, email, contraseña, fecha nacimiento
- Botones de género (Masculino/Femenino) con borde naranja
- Checkbox de términos con texto naranja
- Botón "Registrarse" naranja
- Link "Ya tienes cuenta? Inicia sesión" al final

### 3. INICIO PAGE (`inicio.dart`)
**Cambios principales:**
- Fondo oscuro
- Header con:
  - Avatar circular del usuario (foto de perfil) en la parte superior izquierda
  - Texto "Hola, {nombre}" en blanco
  - Icono de notificaciones arriba derecha
- Barra de búsqueda con fondo #2C2C2E y placeholder gris
- Sección "Salones destacados cerca de ti" con cards horizontales que muestran:
  - Imagen del salón
  - Nombre del salón
  - Calificación con estrellas amarillas
  - Distancia en km
- Grid de categorías con iconos naranjas en círculos oscuros:
  - Peluquería (✂️)
  - Maquillaje (💄)
  - Masajes (💆)
  - Uñas (💅)
  - Faciales (😊)
  - Depilación (🏠)
- Bottom navigation bar oscuro con íconos naranjas cuando están seleccionados

### 4. SALON PROFILE PAGE (`salon_profile_page.dart`)
**Cambios principales:**
- Imagen hero full-width en la parte superior
- Botón de corazón (favorito) flotante blanco arriba derecha
- Nombre del salón en blanco, grande y bold
- Calificación con estrellas amarillas y número de opiniones
- Dirección con ícono de ubicación
- Tabs: "Servicios" y "Reseñas" con indicador naranja
- Lista de servicios con fondo #2C2C2E:
  - Nombre del servicio
  - Duración en minutos
  - Precio en lempiras alineado a la derecha
  - Botón "+" naranja para agregar
- Botón "Agendar Cita" naranja fijo en la parte inferior

### 5. CALENDAR PAGE / BOOKING (`calendar_page.dart`)
**Modal emergente al agendar:**
```
┌─────────────────────────────────────┐
│  Confirmar tu Cita                   │
│                                      │
│  ✂️  Corte de Pelo Moderno          │
│      Salón Beauteek                  │
│                                      │
│  📅  Martes, 28 de Mayo a las 15:30 │
│                                      │
│  🏷️  Precio Total: 45.00 €          │
│                                      │
│  [Cancelar]  [Confirmar Cita]       │
└─────────────────────────────────────┘
```
**Estilo:**
- Fondo #2C2C2E redondeado
- Iconos naranjas
- Botón "Confirmar Cita" naranja
- Botón "Cancelar" con borde naranja

### 6. PAYMENT SCREEN (`payment_screen.dart`)
**Cambios principales:**
- Fondo oscuro
- Card superior con resumen:
  - "Valor del Servicio: $50.000"
  - "Comisión Beauteek (5%): $5.000"
  - "Total a Pagar: $55.000" (naranja y grande)
- Sección "Método de Pago"
- Campo de tarjeta con ícono de tarjeta
- Campos de fecha y CVV en línea
- Mensaje "Tu pago es 100% seguro" con ícono de escudo verde
- Botón "Pagar $55.000" naranja

### 7. PROFILE MENU (`profile_menu.dart`)
**Cambios principales:**
- Fondo oscuro
- Avatar circular grande arriba
- Nombre del usuario en blanco
- Texto "Perfil personal" en gris
- Cards con opciones:
  - Perfil
  - Favoritos (solo clientes)
  - Mis reseñas (solo clientes)
  - Registrar mi salón (solo clientes)
  - Configurar servicios (solo salones)
  - Reportes detallados (solo salones)
- Botón "Cerrar sesión" con ícono de logout
- Cada opción con ícono redondeado naranja a la izquierda

### 8. FAVORITOS PAGE (`favoritos_page.dart`)
**Cambios principales:**
- Barra de búsqueda arriba
- Lista de salones favoritos con:
  - Imagen cuadrada del salón
  - Nombre del salón
  - Calificación con estrellas
  - Ubicación
  - Botón de corazón naranja lleno
- Mensaje vacío: "Guarda tus salones preferidos" con ícono de corazón grande

### 9. MIS RESEÑAS PAGE (`mis_resenas_page.dart`)
**Cambios principales:**
- Lista de cards con:
  - Icono/logo del salón
  - Nombre del salón
  - Servicio recibido
  - 5 estrellas naranjas
  - Comentario en texto gris
  - Fecha de la reseña

### 10. SEARCH PAGE (`search_page.dart`)
**Cambios principales:**
- Barra de búsqueda arriba con fondo #2C2C2E
- Filtros horizontales con chips:
  - "Ordenar" con dropdown
  - "Distancia"
  - "Precio"
- **NUEVO:** Tabs para segmentar:
  - "Salones" (seleccionado con barra naranja abajo)
  - "Servicios"
- Lista de resultados según el tab seleccionado:
  - **Salones:** Logo, nombre, categoría, distancia, precio estimado, calificación
  - **Servicios:** Ícono de servicio, nombre, salón que lo ofrece, precio, duración
- Botón flotante naranja "Ver en Mapa"

## 🔧 Componentes Reutilizables a Crear

### 1. Custom App Bar
```dart
PreferredSizeWidget buildCustomAppBar({
  required String title,
  List<Widget>? actions,
  bool showBackButton = true,
}) {
  return AppBar(
    backgroundColor: AppTheme.darkBackground,
    elevation: 0,
    leading: showBackButton ? BackButton(color: Colors.white) : null,
    title: Text(title, style: AppTheme.heading3),
    actions: actions,
  );
}
```

### 2. Primary Button
```dart
Widget buildPrimaryButton({
  required String text,
  required VoidCallback onPressed,
  bool isLoading = false,
}) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: AppTheme.primaryButtonStyle(),
      child: isLoading
          ? CircularProgressIndicator(color: Colors.white)
          : Text(text),
    ),
  );
}
```

### 3. Input Field
```dart
Widget buildInputField({
  required TextEditingController controller,
  required String label,
  required String hint,
  IconData? prefixIcon,
  Widget? suffixIcon,
  bool obscureText = false,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
      SizedBox(height: 8),
      Container(
        decoration: AppTheme.cardDecoration(),
        child: TextField(
          controller: controller,
          style: AppTheme.bodyLarge,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: AppTheme.inputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ),
    ],
  );
}
```

### 4. Service Card
```dart
Widget buildServiceCard({
  required String name,
  required int duration,
  required double price,
  required VoidCallback onAdd,
}) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    padding: EdgeInsets.all(16),
    decoration: AppTheme.elevatedCardDecoration(),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTheme.heading3.copyWith(fontSize: 16)),
              SizedBox(height: 4),
              Text('$duration min', style: AppTheme.caption),
            ],
          ),
        ),
        Text(
          'L${price.toStringAsFixed(2)}',
          style: AppTheme.heading3.copyWith(color: AppTheme.primaryOrange),
        ),
        SizedBox(width: 12),
        IconButton(
          icon: Icon(Icons.add_circle, color: AppTheme.primaryOrange, size: 32),
          onPressed: onAdd,
        ),
      ],
    ),
  );
}
```

### 5. Salon Card (Horizontal)
```dart
Widget buildSalonCard({
  required String name,
  required double rating,
  required double distance,
  required String? imageUrl,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 200,
      margin: EdgeInsets.only(right: 12),
      decoration: AppTheme.elevatedCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl != null
                ? Image.network(imageUrl, height: 120, width: 200, fit: BoxFit.cover)
                : Container(
                    height: 120,
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                    child: Icon(Icons.store, size: 48, color: Colors.white),
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTheme.heading3.copyWith(fontSize: 14)),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text('$rating', style: AppTheme.caption),
                    Spacer(),
                    Icon(Icons.place, color: AppTheme.textSecondary, size: 16),
                    SizedBox(width: 4),
                    Text('${distance.toStringAsFixed(1)} km', style: AppTheme.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

## 🚀 Orden de Implementación Sugerido

1. ✅ Crear theme/app_theme.dart (YA CREADO)
2. Actualizar main.dart para usar el tema oscuro
3. Rediseñar login_screen.dart y register_screen.dart (pantallas de auth)
4. Rediseñar inicio.dart (pantalla principal)
5. Rediseñar salon_profile_page.dart (vista del salón)
6. Actualizar modal de confirmación en calendar_page.dart
7. Rediseñar payment_screen.dart
8. Rediseñar profile_menu.dart
9. Rediseñar favoritos_page.dart y mis_resenas_page.dart
10. Rediseñar search_page.dart (con tabs de Salones/Servicios)

## 📝 Notas Importantes

- **NO** agregar opciones de "Distancia" ni "Precio" en search_page (por petición del usuario)
- El avatar circular en inicio SOLO se muestra si el rol es "cliente"
- Los colores deben ser EXACTOS a los mockups proporcionados
- Todos los botones primarios usan #FF9500
- Todas las cards usan #2C2C2E con bordes redondeados
- Las estrellas de calificación son amarillas (#FFB800)
- Los íconos de navegación activos son naranjas

## 🎯 Características Especiales

### Modal de Confirmación de Cita
- Fondo semitransparente oscuro
- Card blanco/gris oscuro centrado
- Iconos de categoría naranjas
- Información organizada con íconos
- Dos botones: uno outline y otro filled

### Bottom Navigation
- Fondo #2C2C2E
- 4 opciones para clientes: Inicio, Buscar, Calendario, Perfil
- 4 opciones para salones: Inicio, Estadísticas, Calendario, Perfil
- Íconos naranjas cuando están seleccionados

### Tabs en Search Page
- Dos opciones: "Salones" y "Servicios"
- Indicador naranja debajo del tab seleccionado
- Contenido diferente según el tab seleccionado
- Resultados con diseño de card oscuro

