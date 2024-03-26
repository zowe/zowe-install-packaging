import * as std from "cm_std";

std.setenv('ZWE_zowe_runtimeDirectory', "/var/product/zowe");

import * as configmgr from '../../../bin/libs/configmgr';

describe('tests of config manager', () => {

  it('getZoweBaseSchemas returns the schema location', () => {
    expect(configmgr.getZoweBaseSchemas())
        .toBe("/var/product/zowe/schemas/zowe-yaml-schema.json:/var/product/zowe/schemas/server-common.json");
  });

});