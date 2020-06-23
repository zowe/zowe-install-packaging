/*
 This program and the accompanying materials are made available
 under the terms of the Eclipse Public License v2.0 which
 accompanies this distribution, and is available at
 https://www.eclipse.org/legal/epl-v20.html

 SPDX-License-Identifier: EPL-2.0

 Copyright Contributors to the Zowe Project. 2020
 */

import java.io.*;
import java.lang.*;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

public class HashFiles {

// input is a filename; file contains a list of filenames to be hashed
   
   public static long RSHash(String str) {
      int b     = 378551;
      int a     = 63689;
      long hash = 0;

      for(int i = 0; i < str.length(); i++) {
         hash = hash * a + str.charAt(i);
         a    = a * b;
      }

      return hash;
   }

   public static String readAllBytesJava7(String filePath) {
       String content = "";

       try {
           content = new String ( Files.readAllBytes( Paths.get(filePath) ) );
       
       } catch (IOException e) {
           System.err.println("IOException reading file " + filePath); 
           System.err.println(e.getMessage()); 
       }

       return content;
   }
   
   public static void main(String args[]) throws IOException {
      File file=new File(args[0]);    
      FileReader fr=new FileReader(file);   
      BufferedReader br=new BufferedReader(fr);  
      String line;  
      while((line=br.readLine())!=null) {  
        String key = readAllBytesJava7( line ) ;
        System.out.println(line + " " + RSHash  (key));
      }  
      fr.close();    
        
   }

}
