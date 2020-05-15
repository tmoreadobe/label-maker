/*
	Copyright 2020 Alexander Vollschwitz

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

	    http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
*/
package labelmaker

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/xelalexv/label-maker/pkg/controller/util"

	core_v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

//
var controllerLog = util.NewControllerLogger("labelmaker.controller")

//
func Add(mgr manager.Manager) error {
	return add(mgr, newReconciler(mgr))
}

//
func newReconciler(mgr manager.Manager) reconcile.Reconciler {
	ret := &LabelMaker{client: mgr.GetClient()}
	label, set := getRoleLabel()
	if set {
		controllerLog.Info("using explicitly set role label", "label", label)
	} else {
		controllerLog.Info("using default role label", "label", label)
	}
	ret.roleLabel = label
	return ret
}

//
func add(mgr manager.Manager, r reconcile.Reconciler) error {

	c, err := controller.New("labelmaker-controller", mgr,
		controller.Options{Reconciler: r})
	if err != nil {
		return err
	}

	// Watch for changes to primary resource Node
	if err := c.Watch(&source.Kind{Type: &core_v1.Node{}},
		&handler.EnqueueRequestForObject{}); err != nil {
		return err
	}

	return nil
}

//
var _ reconcile.Reconciler = &LabelMaker{}

//
type LabelMaker struct {
	// This client, initialized using mgr.Client() above, is a split client
	// that reads objects from the cache and writes to the API server
	client    client.Client
	roleLabel string
}

//
func (lm *LabelMaker) Reconcile(req reconcile.Request) (reconcile.Result, error) {

	log := controllerLog.LoggerForRequest("node", req)
	res := reconcile.Result{}

	log.Debug("reconciling")

	node := &core_v1.Node{}
	if err := lm.client.Get(
		context.TODO(), req.NamespacedName, node); err != nil {
		if errors.IsNotFound(err) {
			return res, log.Info("node resource not found, ignoring")
		}
		return res, log.Error(err, "failed to get node")
	}

	return lm.handle(node)
}

//
func (lm *LabelMaker) handle(node *core_v1.Node) (reconcile.Result, error) {

	log := controllerLog.LoggerForNode(node)
	res := reconcile.Result{}

	labels := node.GetLabels()
	role, ok := labels[lm.roleLabel]
	if !ok {
		return res, log.Debug("no role label present")
	}

	for k, _ := range labels {
		if strings.HasPrefix(k, "node-role.kubernetes.io/") {
			return res, log.Debug("node-role already set")
		}
	}

	log.Info("setting node-role", "role", role)
	labels[fmt.Sprintf("node-role.kubernetes.io/%s", role)] = ""

	err := util.UpdateNode(lm.client, node,
		func(n *core_v1.Node) {
			n.SetLabels(labels)
		})
	if err != nil {
		return res, log.Error(err, fmt.Sprintf("failed to update labels"))
	}

	return res, nil
}

//
func getRoleLabel() (string, bool) {
	label := os.Getenv("ROLE_LABEL")
	if label == "" {
		return "node.kubernetes.io/role", false
	}
	return label, true
}
