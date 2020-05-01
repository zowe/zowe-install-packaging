For workflow versioning, use
		<workflowVersion>###ZOWE_VERSION###</workflowVersion>

---

Do this for workflows that do not share source with a shipped JCL:
- create workflow as workflows/files/<id>.xml
- create variable definitions as workflows/files/<id>.properties

During build, .pax/prepare-workspace.sh will:
- substitute ###ZOWE_VERSION###
- create zowe-<vrm>/files/workflows/*

---

Do this for workflows that share source with a single shipped JCL:
- create workflow as workflows/templates/<id>.xml, using
	    <inlineTemplate substitution="true">###./<id>.vtl###</inlineTemplate>
- create variable definitions as workflows/templates/<id>.properties
- create shared JCL source as workflows/templates/<id>.vtl

During build, .pax/prepare-workspace.sh will:
- substitute ###ZOWE_VERSION###
- create templates/*

During build, .pax/pre-packaging.sh will:
- create the JCL, for example as zowe-<vrm>/files/jcl/<id>.jcl
- create the workflow, for example as zowe-<vrm>/files/workflows/<id>.xml
- create the variable definitions, for example as zowe-<vrm>/files/workflows/<id>.properties

---

Do this for workflows that share source with multiple shipped JCL:
- create workflow as workflows/templates/<id>.xml, using
	    <inlineTemplate substitution="true">###./<id>/<jcl>.vtl###</inlineTemplate>
- create directory workflows/templates/<id>
- create workflow variable definitions as workflows/templates/<id>.properties
- create JCL variable definitions as workflows/templates/<id>/<jcl>.properties
- create shared JCL source as workflows/templates/<id>/<jcl>.vtl

During build, .pax/prepare-workspace.sh will:
- substitute ###ZOWE_VERSION###
- create templates/*

During build, .pax/pre-packaging.sh will:
- create the JCLs, for example as smpe/pax/MVS/<jcl>.jcl
- create the workflow, for example as smpe/pax/USS/<id>.xml
- create the variable definitions, for example as smpe/pax/USS/<id>.properties
