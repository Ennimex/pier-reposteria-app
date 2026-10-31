# Certificados de prueba (#219)

Solo para `test/unitarias/comun/cliente_seguro_test.dart`: un servidor HTTPS
en `localhost` con un certificado que **no** es el del API, para comprobar que
el cliente con el certificado fijado lo rechaza.

- `autoridad.pem`: autoridad de prueba (su llave privada no se guardó).
- `servidor.pem` y `servidor.key`: certificado de `localhost` y `127.0.0.1`
  firmado por esa autoridad, y su llave. No protegen nada: solo existen para
  esta prueba.

Se generaron con `openssl` (curva P-256, vigencia de 100 años):

```sh
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout autoridad.key -out autoridad.pem -days 36500 \
  -subj "/O=Pier pruebas/CN=Autoridad de prueba" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout servidor.key -out servidor.csr -subj "/O=Pier pruebas/CN=localhost"
openssl x509 -req -in servidor.csr -CA autoridad.pem -CAkey autoridad.key \
  -CAcreateserial -out servidor.pem -days 36500 \
  -extfile <(printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nbasicConstraints=CA:FALSE\nextendedKeyUsage=serverAuth\n')
```
