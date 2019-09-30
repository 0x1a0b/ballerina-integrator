// Copyright (c) 2019 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

package org.wso2.integration.ballerina.util;

import org.ballerinalang.langserver.compiler.LSContext;
import org.ballerinalang.model.elements.PackageID;
import org.wso2.ballerinalang.compiler.tree.BLangImportPackage;
import org.wso2.ballerinalang.compiler.tree.BLangPackage;

import java.util.List;

public class ServiceKeys {
    public static final LSContext.Key<String> RELATIVE_FILE_PATH_KEY
            = new LSContext.Key<>();
    public static final LSContext.Key<PackageID> CURRENT_PACKAGE_ID_KEY
            = new LSContext.Key<>();
    public static final LSContext.Key<BLangPackage> CURRENT_BLANG_PACKAGE_CONTEXT_KEY
            = new LSContext.Key<>();
    public static final LSContext.Key<List<BLangImportPackage>> CURRENT_DOC_IMPORTS_KEY
            = new LSContext.Key<>();

}
