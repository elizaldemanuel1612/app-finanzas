/// Estados de un [Movimiento] (spec-app-finanzas-v2.md §1.4).
///
/// Sin bandeja de pendientes: todo lo que el usuario registra entra
/// [activo] de inmediato. Solo lo que el sistema genera solo (recurrencias
/// de fijos) nace [propuesto] y requiere confirmación. [anulado] es el
/// único "borrado" que existe — nunca se elimina físicamente antes de
/// 30 días (regla no negociable #3).
enum EstadoMovimiento { activo, propuesto, anulado }
