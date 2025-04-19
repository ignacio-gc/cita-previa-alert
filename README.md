# Cita previa alert

Cita previa alert es una pequeña aplicación que cree para practicar Haskell y al mismo tiempo enterarme cuándo hay fecha para renovar el pasaporte Español. La aplicación solamente consulta la página https://www.cgeonline.com.ar/informacion/apertura-de-citas.html y chquea la fila "Pasaportes
renovación y primera vez". Si dicha fila tiene en su tercer columna algo distinto a "fecha por confirmar" entonces envía un mail con la fecha y el link para solicitar al mail que se haya registrado en `/config/confing.xml`.

## Archivo de configuración
En la carpeta `config` tiene que haber un archivo `config.xml` con una estructura similar a la siguiente:

```
<conf>
  <mail-addr>algunnombredemail@mail.com</mail-addr>
  <mail-pass>password para poder enviar mail</mail-pass>
  <email-to-name>Un nombre</email-to-name>
</conf>
```
