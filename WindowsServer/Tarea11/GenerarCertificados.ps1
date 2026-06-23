mkdir nginx\ssl -Force
openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
  -keyout nginx\ssl\mail.reprobados.com.key `
  -out nginx\ssl\mail.reprobados.com.crt `
  -subj "/CN=localhost"