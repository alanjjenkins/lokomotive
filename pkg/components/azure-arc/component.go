// Copyright 2021 The Lokomotive Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package azurearc

import (
	"fmt"
	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/gohcl"
	internaltemplate "github.com/kinvolk/lokomotive/internal/template"

	"github.com/kinvolk/lokomotive/pkg/components"
	"github.com/kinvolk/lokomotive/pkg/components/util"
	"github.com/kinvolk/lokomotive/pkg/k8sutil"
)

const (
	// Name represents azure-arc component name as it should be referenced in function calls
	// and in configuration.
	Name = "azure-arc-lokomotive"
)

type component struct {
	ApplicationClientID string `hcl:"application_client_id"`
	TenantID            string `hcl:"tenant_id"`
	ApplicationPassword string `hcl:"application_password"`
	ResourceGroup       string `hcl:"resource_group"`
	ClusterName         string `hcl:"cluster_name"`
	Namespace           string
}

// NewConfig returns new azure-arc component configuration with default values set.
//
//nolint:golint
func NewConfig() *component {
	return &component{
		Namespace: "azure-arc-onboarding",
	}
}

func (c *component) LoadConfig(configBody *hcl.Body, evalContext *hcl.EvalContext) hcl.Diagnostics {
	if configBody == nil {
		return hcl.Diagnostics{
			components.HCLDiagConfigBodyNil,
		}
	}

	diags := gohcl.DecodeBody(*configBody, evalContext, c)
	if diags.HasErrors() {
		return diags
	}

	return c.validateConfig()
}

func (c *component) RenderManifests() (map[string]string, error) {
	helmChart, err := components.Chart(Name)
	if err != nil {
		return nil, fmt.Errorf("retrieving chart from assets: %w", err)
	}

	values, err := internaltemplate.Render(chartValuesTmpl, c)
	if err != nil {
		return nil, fmt.Errorf("rendering values template failed: %w", err)
	}

	// Generate YAML for the azure-arc pod.
	renderedFiles, err := util.RenderChart(helmChart, Name, c.Metadata().Namespace.Name, values)
	if err != nil {
		return nil, fmt.Errorf("rendering chart failed: %w", err)
	}

	return renderedFiles, nil
}

func (c *component) Metadata() components.Metadata {
	return components.Metadata{
		Name: Name,
		Namespace: k8sutil.Namespace{
			Name: c.Namespace,
		},
	}
}

func (c *component) validateConfig() hcl.Diagnostics {
	diags := hcl.Diagnostics{}

	if len(c.TenantID) == 0 {
		diags = append(diags, &hcl.Diagnostic{
			Severity: hcl.DiagError,
			Summary:  "Validation of configuration failed: expected non-empty value",
			Detail:   "`tenant_id` cannot be an empty value",
		})
	}

	if len(c.ApplicationClientID) == 0 {
		diags = append(diags, &hcl.Diagnostic{
			Severity: hcl.DiagError,
			Summary:  "Validation of configuration failed: expected non-empty value",
			Detail:   "`application_client_id` cannot be an empty value",
		})
	}

	if len(c.ApplicationPassword) == 0 {
		diags = append(diags, &hcl.Diagnostic{
			Severity: hcl.DiagError,
			Summary:  "Validation of configuration failed: expected non-empty value",
			Detail:   "`application_password` cannot be an empty value",
		})
	}

	return diags
}
