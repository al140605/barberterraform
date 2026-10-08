# Modulos

Agregar aqui modulos cuando se implementen las historias de provisionamiento. La
estructura prevista, basada en el staging actual, es:

- `networking/`: VPC/subredes existentes y grupos de seguridad.
- `alb/`: balanceador, listeners y grupos de destino.
- `compute/`: ECR, cluster ECS, task definitions y servicios Fargate.
- `storage/`: buckets S3, politicas y logs.
- `edge/`: CloudFront, ACM y DNS Route 53.
- `atlas/`: recursos de MongoDB Atlas, solo tras confirmar el alcance de gestion.

Los modulos deben adoptar recursos existentes por importacion y evitar reemplazos
accidentales. No crear una VPC nueva: staging usa actualmente la VPC predeterminada.