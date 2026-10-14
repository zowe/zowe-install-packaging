/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2021
 */

import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.security.Key;
import java.security.KeyStore;
import java.util.Base64;
import com.ibm.crypto.zsecurity.provider.RACFInputStream;

public class ExportPrivateKeyZos {
    private String keystoreName;
    private String keyStoreType;
    private char[] keyStorePassword;
    private char[] keyPassword;
    private String alias;
    private File exportedFile;

    public void export() throws Exception {
        KeyStore keystore = KeyStore.getInstance(keyStoreType);
        if ((keyStoreType != null) && keyStoreType.toUpperCase().startsWith("JCE") && keyStoreType.toUpperCase().endsWith("KS")) {
            String splits[] = keystoreName.replaceFirst("safkeyring://", "").split("/");
            keystore.load(new RACFInputStream(splits[0], splits[1], keyStorePassword), keyStorePassword);

        } else {
            keystore.load(new FileInputStream(new File(keystoreName)), keyStorePassword);
        }
        Key key = keystore.getKey(alias, keyPassword);
        String encoded = Base64.getEncoder().encodeToString(key.getEncoded());
        FileWriter fw = new FileWriter(exportedFile);
        fw.write("-----BEGIN PRIVATE KEY-----");
        for (int i = 0; i < encoded.length(); i++) {
            if (((i % 64) == 0) && (i != (encoded.length() - 1))) {
                fw.write("\n");
            }
            fw.write(encoded.charAt(i));
        }
        fw.write("\n");
        fw.write("-----END PRIVATE KEY-----\n");
        fw.close();
    }

    public static void main(String args[]) throws Exception {
        // the password is read from the environment, not from args, so it is not
        // readable from this process's arguments by another user inspecting processes
        String password = System.getenv("ZWE_PRIVATE_EXPORTPRIVATEKEY_PASSWORD");
        if (password == null) {
            System.err.println("ZWE_PRIVATE_EXPORTPRIVATEKEY_PASSWORD is not set");
            System.exit(1);
        }
        ExportPrivateKeyZos export = new ExportPrivateKeyZos();
        export.keystoreName = args[0];
        export.keyStoreType = args[1];
        export.keyStorePassword = password.toCharArray();
        export.alias = args[2];
        export.keyPassword = password.toCharArray();
        export.exportedFile = new File(args[3]);
        export.export();
    }
}
