const express = require('express');
const cors = require('cors');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
const { verifyToken } = require('@clerk/backend');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Configurar CORS - permite cualquier origen ya que frontend y backend están en el mismo servidor
app.use(cors({
  origin: '*',
  credentials: true
}));
app.use(express.json());

// Conexión a Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

console.log('Conectado a Supabase');

// Middleware de autenticación con Clerk
const requireAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ mensaje: 'Token no proporcionado' });
    }
    const token = authHeader.split(' ')[1];
    const payload = await verifyToken(token, {
      secretKey: process.env.CLERK_SECRET_KEY
    });
    req.auth = payload;
    next();
  } catch (error) {
    console.error('Error al verificar token:', error);
    res.status(401).json({ mensaje: 'No autorizado' });
  }
};

// Endpoint de prueba
app.get('/api/saludo', (req, res) => {
  res.json('Hola mundo');
});

// GET - Información del usuario autenticado
app.get('/api/auth/me', requireAuth, async (req, res) => {
  res.json({ userId: req.auth.userId });
});

// GET - Obtener todos los eventos
app.get('/api/eventos', requireAuth, async (req, res) => {
  try {
    console.log('Obteniendo eventos...');
    const { data, error } = await supabase
      .from('eventos')
      .select('*')
      .order('fecha', { ascending: true })
      .order('hora', { ascending: true });
    
    console.log('Data:', data);
    console.log('Error:', error);
    
    if (error) throw error;
    res.json(data || []);
  } catch (error) {
    console.error('Error al obtener eventos:', error);
    res.status(500).json({ mensaje: 'Error al obtener eventos' });
  }
});

// GET - Obtener evento por ID
app.get('/api/eventos/:id', requireAuth, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('eventos')
      .select('*')
      .eq('id', req.params.id)
      .single();
    
    if (error) throw error;
    if (!data) {
      return res.status(404).json({ mensaje: 'Evento no encontrado' });
    }
    res.json(data);
  } catch (error) {
    res.status(500).json({ mensaje: 'Error al obtener evento' });
  }
});

// POST - Crear nuevo evento
app.post('/api/eventos', requireAuth, async (req, res) => {
  try {
    const { titulo, descripcion, fecha, hora, latitud, longitud } = req.body;
    
    if (!titulo || !fecha) {
      return res.status(400).json({ mensaje: 'Título y fecha son requeridos' });
    }
    
    const { data, error } = await supabase
      .from('eventos')
      .insert([
        { titulo, descripcion: descripcion || '', fecha, hora: hora || '', latitud, longitud }
      ])
      .select();
    
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ mensaje: 'Error al crear evento' });
  }
});

// PUT - Actualizar evento
app.put('/api/eventos/:id', requireAuth, async (req, res) => {
  try {
    const { titulo, descripcion, fecha, hora } = req.body;
    
    const { data, error } = await supabase
      .from('eventos')
      .update({ titulo, descripcion, fecha, hora })
      .eq('id', req.params.id)
      .select();
    
    if (error) throw error;
    if (!data || data.length === 0) {
      return res.status(404).json({ mensaje: 'Evento no encontrado' });
    }
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ mensaje: 'Error al actualizar evento' });
  }
});

// DELETE - Eliminar evento
app.delete('/api/eventos/:id', requireAuth, async (req, res) => {
  try {
    const { error } = await supabase
      .from('eventos')
      .delete()
      .eq('id', req.params.id);
    
    if (error) throw error;
    res.json({ mensaje: 'Evento eliminado' });
  } catch (error) {
    res.status(500).json({ mensaje: 'Error al eliminar evento' });
  }
});

// Servir archivos estáticos del frontend (build de Vite)
app.use(express.static(path.join(__dirname, '../FRONTEND/dist')));

// Ruta catch-all para SPA - sirve index.html del build
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../FRONTEND/dist/index.html'));
});

app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});
