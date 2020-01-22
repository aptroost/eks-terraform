# Jupyter notebook

Create the namespace:

```cmd
k create ns jupyter
```

Create a password `auth` file:

```cmd
htpasswd -c auth dobdata
```

Now create the secret for log-in and delete the auth file:

```cmd
k create secret -n jupyter generic basic-auth --from-file=auth --save-config
rm auth
```

Create secrets for PostgreSQL superuser:

```cmd
kubectl create secret generic pg-su \
  --namespace jupyter \
  --from-literal=username='su_username' --from-literal=password='su_password'
```
