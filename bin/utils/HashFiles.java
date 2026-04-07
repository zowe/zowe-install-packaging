/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020, 2020
 */

import java.io.*;
import java.nio.charset.Charset;

public class HashFiles {

// input is a filename; file contains a list of filenames to be hashed

    public static long RSHash(byte[] data) {
        int b = 378551;
        int a = 63689;
        long hash = 0;

        for (int i = 0; i < data.length; i++) {
            hash = hash * a + (data[i] & 0xFF);
            a = a * b;
        }
        return hash;
    }

    public static byte[] readFileBytes(String filePath) throws IOException {
        try (FileInputStream fis = new FileInputStream(filePath)) {
            return fis.readAllBytes();
        } catch (IOException e) {
            System.err.println("IOException reading file " + filePath);
            System.err.println(e.getMessage());
            throw e;
        }
    }

    public static void main(String args[]) throws IOException {
        File file = new File(args[0]);
        String nativeEnc = System.getProperty("native.encoding");
        Charset nativeCharset = nativeEnc != null
            ? Charset.forName(nativeEnc)
            : Charset.defaultCharset();
        BufferedReader br = new BufferedReader(
            new InputStreamReader(new FileInputStream(file), nativeCharset));
        String line;
        while ((line = br.readLine()) != null) {
            byte[] content = readFileBytes(line);
            System.out.println(line + " " + RSHash(content));
        }
        br.close();
    }
}