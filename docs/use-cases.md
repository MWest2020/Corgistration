# Use Cases

Real-world scenarios where corgistration helps you diagnose and fix Kubernetes issues faster.

---

## 1. CrashLoopBackOff Pod

**Symptom**: A pod keeps restarting. K9s shows `CrashLoopBackOff`.

**What to do**:
```bash
corgi Pod <name> <namespace>
# or press Shift-A on the pod in K9s
```

**What Claude does**: Reads the logs and events, identifies whether it's a config error, missing secret, bad entrypoint, or OOM kill, and tells you which.

**Example outcome**:
> Status: CrashLoopBackOff (3 restarts)
> Issue: Container exits with code 1 — logs show `Error: DATABASE_URL not set`
> Fix: The pod is missing an env var. Check your Deployment's `envFrom` or `env` section and verify the referenced Secret/ConfigMap exists.

You then verify in the terminal pane:
```bash
kubectl get secret my-db-secret -n <namespace>
kubectl describe deployment <name> -n <namespace>
```

---

## 2. Deployment stuck — pods not scheduling

**Symptom**: `kubectl get pods` shows `Pending` indefinitely.

**What to do**:
```bash
corgi Deployment <name> <namespace>
```

**What Claude does**: Reads events section from `kubectl describe`. Common causes it surfaces: insufficient CPU/memory on nodes, node selector mismatch, taint/toleration issues, PVC binding failures.

**Example outcome**:
> Status: 0/3 ready
> Issue: Events show `0/3 nodes are available: 3 Insufficient memory`
> Fix: Your requested memory (4Gi) exceeds available node capacity. Either reduce the request or add a node.

---

## 3. Service not reachable

**Symptom**: An application can't connect to a Service by DNS name.

**What to do**:
```bash
corgi Service <name> <namespace>
```

**What Claude does**: Reads the Service spec — checks selector labels match pod labels, verifies port/targetPort alignment, identifies if the service has no endpoints.

**Example outcome**:
> Status: ClusterIP service, 0 endpoints
> Issue: Selector `app=api` matches no running pods. The Deployment uses label `app=api-server`.
> Fix: Update the Service selector to `app: api-server` or relabel the pods.

---

## 4. StatefulSet rolling update stuck

**Symptom**: A StatefulSet update has been in progress for a long time with pods partially updated.

**What to do**:
```bash
corgi StatefulSet <name> <namespace>
```

**What Claude does**: Reads the StatefulSet spec and events, checks `updateStrategy`, identifies if a pod is stuck in `Pending` or `Error` blocking the ordered rollout.

**Example outcome**:
> Status: 1/3 ready (update stalled at pod-1)
> Issue: pod-1 is in `Init:Error` — init container fails because the PVC from a previous pod hasn't been released yet.
> Fix: Describe pod-1 and check the init container logs for the exact error.

---

## 5. OOMKilled — container memory issue

**Symptom**: Pod is restarting, K9s shows `OOMKilled` as last state reason.

**What to do**:
```bash
corgi Pod <name> <namespace>
```

**What Claude does**: Reads container status (previous state shows OOMKilled), checks the memory limit in the spec, looks at logs for memory growth patterns.

**Example outcome**:
> Status: OOMKilled (limit: 256Mi)
> Issue: Container exceeded its 256Mi memory limit. Logs show heap growing continuously — likely a memory leak or insufficient limit for the workload.
> Fix: Either increase the memory limit in the Deployment spec, or investigate the memory leak in the application.

To check current resource usage (run in your terminal pane):
```bash
kubectl top pod <name> -n <namespace>
```

---

## 6. ArgoCD application out of sync

**Symptom**: ArgoCD shows an application as `OutOfSync` or `Degraded`.

**What to do**: Navigate to the ArgoCD deployment or the underlying pod in the picker and diagnose it. You can also use corgi on the ArgoCD server pod itself if the UI is unreachable.

```bash
corgi Deployment argocd-server argocd
```

---

## 7. Investigating a healthy resource before making changes

**Symptom**: No problem — you just want to understand a resource before editing it.

**What to do**:
```bash
corgi Deployment <name> <namespace>
```

Use the YAML pane (left) to read the full manifest. Ask Claude follow-up questions in the right pane:

> "What does the readinessProbe do here and is the threshold reasonable?"
> "Are there any security concerns with this pod spec?"
> "What would happen if I scaled this to 0?"

Claude reads the actual manifest and gives context-aware answers.

---

## Tips

- **Filter in the picker**: press `/` and type to narrow by name, namespace, or kind
- **Switch resources quickly**: `Ctrl-b g` opens the picker without leaving the session — all panes refresh on selection
- **Run suggestions in the terminal pane**: bottom-right shell has your full kubeconfig — paste and run kubectl commands there
- **Scroll the YAML pane**: `Ctrl-b [` enters scroll mode, arrow keys navigate, `q` exits
- **Copy Claude output**: click the Claude pane to focus it, then `Shift+drag` to select text with your terminal
