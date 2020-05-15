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
package util

import (
	"context"
	"fmt"

	"github.com/go-logr/logr"
	core_v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/util/retry"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	logf "sigs.k8s.io/controller-runtime/pkg/runtime/log"
)

//
type MetaRuntimeObject interface {
	metav1.Object
	runtime.Object
}

//
func UpdateNode(client client.Client, node *core_v1.Node,
	modify func(node *core_v1.Node)) error {
	modifyObj := func(obj MetaRuntimeObject) {
		modify(obj.(*core_v1.Node))
	}
	return UpdateObject(client, node, modifyObj)
}

//
func UpdateObject(cl client.Client, obj MetaRuntimeObject,
	modify func(MetaRuntimeObject)) error {

	key := types.NamespacedName{
		Name:      obj.GetName(),
		Namespace: obj.GetNamespace(),
	}

	retryErr := retry.RetryOnConflict(retry.DefaultRetry, func() error {

		// get latest version of object
		if err := cl.Get(context.TODO(), key, obj); err != nil {
			return err
		}

		modify(obj)

		return cl.Update(context.TODO(), obj)
	})

	if retryErr != nil {
		return fmt.Errorf("failed to update object: %v", retryErr)
	}

	return nil
}

//
type ControllerLogger struct {
	logr.Logger
}

//
func NewControllerLogger(name string) *ControllerLogger {
	return &ControllerLogger{logf.Log.WithName(name)}
}

//
func (l *ControllerLogger) LoggerForRequest(kind string, req reconcile.Request,
	keysAndValues ...interface{}) *ControllerLogger {
	return l.NamespaceNameLogger(kind, req.Namespace, req.Name, keysAndValues)
}

//
func (l *ControllerLogger) LoggerForNode(node *core_v1.Node,
	keysAndValues ...interface{}) *ControllerLogger {
	return l.NamespaceNameLogger("node", "", node.Name, keysAndValues)
}

//
func (l *ControllerLogger) NamespaceNameLogger(kind, namespace, name string,
	keysAndValues ...interface{}) *ControllerLogger {

	var kv []interface{}

	if kind != "" {
		if namespace != "" {
			kv = []interface{}{
				fmt.Sprintf("%s.namespace", kind), namespace,
				fmt.Sprintf("%s.name", kind), name,
			}
		} else {
			kv = []interface{}{
				fmt.Sprintf("%s.name", kind), name,
			}
		}
	} else if namespace != "" {
		kv = []interface{}{"namespace", namespace, "name", name}
	} else {
		kv = []interface{}{"name", name}
	}

	if len(keysAndValues) > 1 {
		kv = append(kv, keysAndValues...)
	}
	return &ControllerLogger{l.WithValues(kv...)}
}

//
func (l *ControllerLogger) Error(err error, msg string,
	keysAndValues ...interface{}) error {
	if err != nil {
		l.Logger.Error(err, msg, keysAndValues...)
	}
	return err
}

//
func (l *ControllerLogger) ErrorResult(err error, msg string,
	keysAndValues ...interface{}) (reconcile.Result, error) {
	return reconcile.Result{}, l.Error(err, msg, keysAndValues...)
}

//
func (l *ControllerLogger) Info(msg string, keysAndValues ...interface{}) error {
	l.Logger.Info(msg, keysAndValues...)
	return nil
}

//
func (l *ControllerLogger) InfoResult(msg string, keysAndValues ...interface{}) (
	reconcile.Result, error) {
	return reconcile.Result{}, l.Info(msg, keysAndValues...)
}

//
func (l *ControllerLogger) Debug(msg string, keysAndValues ...interface{}) error {
	l.Logger.V(5).Info(msg, keysAndValues...)
	return nil
}
