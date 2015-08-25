// main.m
//
// Copyright (c) 2014 Mattt Thompson
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>

#import "TTTDictionary.h"
#import <libgen.h>


NSString *GetDictionaryNameFromBundlePath(NSString *bundlePath) {
    NSString *infoPlistPath = [bundlePath stringByAppendingString:@"/Contents/Info.plist"];
    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
    NSString *displayName = [infoPlist objectForKey:@"CFBundleDisplayName"];
    return displayName;
}

NSMutableArray *GetActiveDictionaryNames() {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dictionaryPrefs = [userDefaults persistentDomainForName:@"Apple Global Domain"];
    NSArray *activeDictionaryBundlePaths = [[dictionaryPrefs objectForKey:@"com.apple.DictionaryServices"]
                                   objectForKey:@"DCSActiveDictionaries"];
    NSMutableArray *activeDictionaryNames = [NSMutableArray array];
    for (NSString *dictionaryBundlePath in activeDictionaryBundlePaths) {
        NSString *dictionaryName = GetDictionaryNameFromBundlePath(dictionaryBundlePath);
        if (dictionaryName) {
            [activeDictionaryNames addObject:dictionaryName];
        }
    }
    return activeDictionaryNames;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSString *type = @"html";
        NSMutableArray *dictionaryNames = GetActiveDictionaryNames();
        if (!dictionaryNames || !dictionaryNames.count) {
            dictionaryNames = [NSMutableArray arrayWithObject:@"牛津英汉汉英词典"];
        }
        NSString *term = @"";
        
        int ch;
        while ((ch = getopt(argc, (char *const *)argv, "t:d:h")) != -1) {
            switch (ch) {
                case 't':
                {
                    type = [NSString stringWithUTF8String:optarg];
                    if (![type isEqualToString:@"text"] &&
                        ![type isEqualToString:@"html"] &&
                        ![type isEqualToString:@"htmlwithcss"]) {
                        fprintf(stderr, "type '%s' is invalid!\n", optarg);
                        return -1;
                    }
                    break;
                }
                case 'd':
                {
                    NSArray *dictionaryNameOrPaths = [[NSString stringWithUTF8String:optarg] componentsSeparatedByString:@","];
                    [dictionaryNames removeAllObjects];
                    for (NSString *dictionaryNameOrPath in dictionaryNameOrPaths) {
                        if ([dictionaryNameOrPath hasSuffix:@".dictionary"]) {
                            NSString *dictionaryName = GetDictionaryNameFromBundlePath(dictionaryNameOrPath);
                            if (dictionaryName) {
                                [dictionaryNames addObject:dictionaryName];
                            }
                        } else {
                            [dictionaryNames addObject:dictionaryNameOrPath];
                        }
                    }
                    if (dictionaryNames.count == 0) {
                        fprintf(stderr, "no valid dictionary names found!\n");
                        return -1;
                    }
                    break;
                }
                case 'h':
                default:
                {
                    fprintf(stderr, "usage: %s [-t type] [-d dictionary] [-h] <term>\n\n", basename((char *)argv[0]));
                    fprintf(stderr, "options:\n"
                                    " -t: content type, available values are 'text', 'html', 'htmlwithcss'.\n"
                                    " -d: dictionaries, either display name or bundle path, separated by comma.\n"
                                    "     if not specified, all currently active dictionaries are used.\n"
                                    " -h: display help text.\n");
                    return 0;
                }
            }
        }
        
        argc -= optind;
        argv += optind;
        if (argc <= 0) {
            fprintf(stderr, "please specify a word or phrase to look up.\n");
            return -1;
        }
        
        NSMutableArray *words = [NSMutableArray array];
        for (int i = 0; i < argc; i++) {
            [words addObject:[NSString stringWithUTF8String:argv[i]]];
        }
        term = [words componentsJoinedByString:@" "];
        
        BOOL dictionaryNotFound = NO;
        for (NSString *dictionaryName in dictionaryNames) {
            TTTDictionary *dictionary = [TTTDictionary dictionaryNamed:dictionaryName];
            if (!dictionary) {
                fprintf(stderr, "\n%s: dictionary not found!\n\n", [dictionaryName UTF8String]);
                dictionaryNotFound = YES;
                continue;
            }
            fprintf(stderr, "\n%s:\n\n", [dictionary.name UTF8String]);
            for (TTTDictionaryEntry *entry in [dictionary entriesForSearchTerm:term]) {
                NSString *definition = @"";
                if ([type isEqualToString:@"text"]) {
                    definition = entry.text;
                } else if ([type isEqualToString:@"html"]) {
                    definition = entry.HTML;
                } else {
                    definition = entry.HTMLWithCSS;
                }
                printf("%s\n", [definition UTF8String]);
            }
        }
        if (dictionaryNotFound) {
            NSMutableArray *availabeDictionaryNames = [NSMutableArray array];
            for (TTTDictionary *dict in [TTTDictionary availableDictionaries]) {
                [availabeDictionaryNames addObject:dict.name];
            }
            fprintf(stderr, "available dictionaries are: \n * %s\n", [[availabeDictionaryNames componentsJoinedByString:@"\n * "] UTF8String]);
            return -1;
        }
    }

    return 0;
}
