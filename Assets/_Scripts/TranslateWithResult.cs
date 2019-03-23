using UnityEngine;
using System.IO;
using System.Collections.Generic;
using System.Text;

public enum Languages
{
    Chinese = 0,
    Korea = 1,
}
public class LanguagesElement
{
    public Languages curLanguages;
    public string key = string.Empty;// 以提取的中文作为key
    public string originText = string.Empty;// 原始版本，带字符、数字
    public List<MyArguments> arguemnts = null;// 提取出来的所有字符数字，这里描述为参数
    public string translateResult = string.Empty;// 翻译的结果
    public LanguagesElement(Languages lan, string str, string inputKey = null)
    {
        curLanguages = lan;
        originText = str;
        arguemnts = new List<MyArguments>(Translator.GetArgument(lan, str, ref key));
        if (inputKey != null)
        {
            key = inputKey;
        }
    }
}
public class TranslateElement
{
    public string key = string.Empty;// 以提取的中文作为key

    public LanguagesElement originLanguages;
    public LanguagesElement targetLanguages;
    public Dictionary<int, int> dicArgumentIndex = new Dictionary<int, int>();// 记录参数翻译成外文后的顺序
    public string errorStr = string.Empty;
    public TranslateElement(string k,string ori,Languages oriLan,string target,Languages targetLan)
    {
        key = k;
        originLanguages = new LanguagesElement(oriLan, ori);
        targetLanguages = new LanguagesElement(targetLan, target);

        CompareArgument();
    }
    public void CompareArgument()
    {
        dicArgumentIndex.Clear();
        List<int> alreadyRead = new List<int>();
        List<MyArguments> origin = originLanguages.arguemnts;
        List<MyArguments> target = targetLanguages.arguemnts;
        for (int i = 0, imax = origin.Count; i < imax; i++)
        {
            bool neverFind = true;
            string replacedArgument = SpecialReplace(origin[i].argument);
            for (int j = 0, jmax = target.Count; j < jmax; j++)
            {
                if (replacedArgument == SpecialReplace(target[j].argument))
                {
                    if(alreadyRead.Contains(j)){
                        continue;
                    }
                    dicArgumentIndex.Add(i,j);
                    alreadyRead.Add(j);
                    neverFind = false;
                    break;
                }
            }
            if (neverFind)
            {
                if(!alreadyRead.Contains(i)){
                    dicArgumentIndex.Add(i, i);
                }
                errorStr += string.Format("{0},{1},{2}\n", origin[i].argument, originLanguages.originText, targetLanguages.originText);
                // Debug.LogError(string.Format("The argument of {0},index of {1} never find\norigin:{2}\ntarget:{3}", origin[i].argument, i, originLanguages.originText, targetLanguages.originText));
            }
        }
    }
    public static string SpecialReplace(string str)
    {
        return ToDBC(str.Replace("Lv.", "").Replace("-", "_"));
    }
    public static string ToDBC(string input)
    {// 全角转半角
        char[] c = input.ToCharArray();
        for (int i = 0; i < c.Length; i++)
        {
            if (c[i] == 12288)
            {
                c[i] = (char)32; continue;
            }
            if (c[i] > 65280 && c[i] < 65375)
                c[i] = (char)(c[i] - 65248);
        }
        return new string(c);
    }
    public string ToSBC(string input)
    { // 半角转全角：
        char[] c = input.ToCharArray();
        for (int i = 0; i < c.Length; i++)
        {
            if (c[i] == 32)
            {
                c[i] = (char)12288; continue;
            }
            if (c[i] < 127) c[i] = (char)(c[i] + 65248);
        }
        return new string(c);
    }
}
public class MyArguments
{
    public int index = 0;
    public string argument = string.Empty;
    public MyArguments(int inputIndex,string inputArgument)
    {
        index = inputIndex;
        argument = inputArgument;
    }
}
public class Translator
{
    public static List<MyArguments> GetArgument(Languages lan, string str, ref string key)
    {
        string argumentStr = string.Empty;
        string indexStr = string.Empty;
        AnalyzeLine(str, ref argumentStr, ref key, ref indexStr, lan);
        string[] arrArg = argumentStr.Split(',');
        string[] arrIndex = indexStr.Split('^');
        List<MyArguments> lst = new List<MyArguments>();
        if (arrArg.Length == 1 && arrArg[0] == string.Empty)
        {
            return lst;
        }
        for (int i = 0, imax = arrArg.Length; i < imax; i++)
        {
            MyArguments newArg = new MyArguments(int.Parse(arrIndex[i]), arrArg[i]);
            lst.Add(newArg);
        }
        return lst;
    }
    static bool IsLanguage(char c, Languages language = Languages.Chinese)
    {
        if (c == ' ' || (char.IsPunctuation(c) && c != '-'))
        {
            return true;
        }
        if (language == Languages.Chinese && System.Text.RegularExpressions.Regex.IsMatch(c.ToString(), @"[\u4e00-\u9fa5]")) // 如果是中文
        {
            return true;
        }
        if (language == Languages.Korea && System.Text.RegularExpressions.Regex.IsMatch(c.ToString(), @"[\uac00-\ud7ff]")) // 如果是韩文
        {
            return true;
        }
        return false;
    }

    // 读取完整语句中的非语言字符组合
    public static int AnalyzeLine(string curLine, ref string CharacterLine, ref string LanguageLine, ref string IndexLine, Languages language = Languages.Chinese)
    {
        if (string.IsNullOrEmpty(curLine)) return 0;
        StringBuilder characterLine = new StringBuilder("");
        StringBuilder languageLine = new StringBuilder("");
        StringBuilder indexLine = new StringBuilder("");
        bool inLanguageArea = false;
        bool preIsLang = false, curIsLang = false;
        int count = 0; // 字符段个数
        int index = 0; // 字符索引

        char curC = curLine[0];
        preIsLang = curIsLang = IsLanguage(curC, language);
        int p = 0;
        // 第一个是字符
        if (!curIsLang) {
            ++p;
            indexLine.Append(index.ToString());
            characterLine.Append(curC);
            ++count;
        }
        for ( ; p < curLine.Length; ++p)
        {
            preIsLang = curIsLang;
            char c = curLine[p];
            curIsLang = IsLanguage(c, language);
            if (curIsLang)
            {
                languageLine.Append(c);
                ++index;
            }
            else
            {
                if (preIsLang) // 从汉字变成了字符
                {
                    if (characterLine.Length > 0) characterLine.Append(",");
                    string str = indexLine.Length > 0 ? string.Format("^{0}", index) : index.ToString();
                    indexLine.Append(str);
                    ++count;
                    // ++index;
                }
                characterLine.Append(c);
            }
        }
        CharacterLine = characterLine.ToString();
        LanguageLine = languageLine.ToString();
        IndexLine = indexLine.ToString();
        return count > 0 ? count + 1 : count;
    }
    public static string AddToAbsolutelyPos(string origin, string addContent, int addIndex, Languages language)
    {
        StringBuilder languageLine = new StringBuilder("");
        if (language != Languages.Chinese)
        {
            addContent = TranslateElement.ToDBC(addContent);
        }
        int count = 0;
        for (int p = 0; p < origin.Length; ++p)
        {
            
            char c = origin[p];
            if (IsLanguage(c, language))
            {
                if (count == addIndex)
                {
                    languageLine.Append(addContent);
                }
                languageLine.Append(c);
                count++;
            }
            else
            {
                languageLine.Append(c);
            }
        }
        if (count == addIndex)
        {
            languageLine.Append(addContent);
        }
        return languageLine.ToString();
    }
    List<LanguagesElement> lstWaitingTranslate = new List<LanguagesElement>();
    Dictionary<string, TranslateElement> dicTranslateResult = new Dictionary<string, TranslateElement>();
    public Languages oriLanguages;
    public Languages targetLanguages;
    public Translator(string pathOri,Languages languagesOri,string pathTarget,Languages languagesTarget)
    {
        oriLanguages = languagesOri;
        targetLanguages = languagesTarget;
        string[] arr = File.ReadAllLines(pathOri);
        for (int i = 0, imax = arr.Length; i < imax; i++)
        {
            LanguagesElement element = new LanguagesElement(languagesOri, arr[i]);
            lstWaitingTranslate.Add(element);
        }
        arr = File.ReadAllLines(pathTarget);
        for (int i = 0, imax = arr.Length; i < imax; i++)
        {
            string[] arrLine = arr[i].Split(',');
            TranslateElement ele = new TranslateElement(arrLine[0], arrLine[1], languagesOri, arrLine[2], languagesTarget);
            dicTranslateResult.Add(ele.key, ele);
        }
    }
    public void Translate (string output,string errorOutput)
    {
        StreamWriter sw = new StreamWriter(output, false, Encoding.UTF8);
        StreamWriter swError = new StreamWriter(errorOutput, false, Encoding.UTF8);

        for (int p = 0, pmax = lstWaitingTranslate.Count; p < pmax;p++)
        {
            LanguagesElement curEle = lstWaitingTranslate[p];
            if (!dicTranslateResult.ContainsKey(curEle.key))
            {
                Debug.LogError("Do not exist translate key:" + curEle.key);
                continue;
            }
            TranslateElement tEle = dicTranslateResult[curEle.key];
            List<MyArguments> curWaitingArguments = curEle.arguemnts;
            string result = string.Empty;
            bool needRecordQuestion = false;
            bool useTargetTransalte = false;
            if (curEle.originText == tEle.originLanguages.originText)
            {
                result = tEle.targetLanguages.originText;
                useTargetTransalte = true;
            }
            else
            {
                result = tEle.targetLanguages.key;
                
                for (int i = 0, imax = curWaitingArguments.Count; i < imax; i++)
                {
                    MyArguments curTemp = curWaitingArguments[i];

                    for (int j = 0, jmax = tEle.originLanguages.arguemnts.Count; j < jmax; j++)
                    {
                        MyArguments temp = tEle.originLanguages.arguemnts[j];

                        if (temp.index == curTemp.index)
                        {
                            if (!tEle.dicArgumentIndex.ContainsKey(j))
                            {
                                needRecordQuestion = true;
                                continue;
                            }
                            int tryToFind = tEle.dicArgumentIndex[j];
                            if (tEle.targetLanguages.arguemnts.Count <= tryToFind)
                            {
                                string tempStr = string.Format("\nCouldn't find argument pos :{0}", temp.argument);
                                Debug.LogError(tempStr);
                                break;
                            }
                            int addIndex = tEle.targetLanguages.arguemnts[tryToFind].index;
                            result = AddToAbsolutelyPos(result, curTemp.argument, addIndex, targetLanguages);
                            break;
                        }
                    }
                }
            }
            if (!useTargetTransalte &&(needRecordQuestion || !string.IsNullOrEmpty(tEle.errorStr)))
            {
                string errorLine = string.Format("{0},{1},{2}", curEle.originText, result, tEle.errorStr);
                swError.WriteLine(errorLine);
            }
            curEle.translateResult = result;
            string newLine = string.Format("{2},{0},{1}", curEle.originText, curEle.translateResult, "Key" + (p + 1));
            sw.WriteLine(newLine);

            // Debug.Log(string.Format("原文：{0} \n译文：{1}", curEle.originText, curEle.translateResult));
            // tEle.originLanguages.arguemnts
        }
        sw.Close();
        swError.Close();
    }
}
public class TranslateWithResult : MonoBehaviour {
    
    public Languages oriLan;   // 源语言
    public Languages targetLan;// 目标语言

    public string testPath = "";

    public string path = "";   // 源文件
    public string translatedPath; // 已经翻译好的文件路径
    public string characterPath = "";        // 完整字符表
    public string translatePath = "";        // 去重后的待翻译原文表   原文key（translateChineseData），最长待翻译语句（translateData）

    public string completePath = "";
    public string errorPath = "";
    
    string[] rawData;
    [ContextMenu("根据给的完整表，生成测试数据")]
    void TestData()
    {
        string[] arr = File.ReadAllLines(GetAbsolutelyPath(testPath));
        string[] testOri = new string[arr.Length];
        Dictionary<string, string> translateDic = new Dictionary<string, string>();
        for (int i = 0, imax = arr.Length; i < imax;i++ )
        {
            string[] arrLine = arr[i].Split(',');
            testOri[i] = arrLine[1];
            if (!translateDic.ContainsKey(testOri[i]))
            {
                translateDic.Add(testOri[i], arrLine[2]);
            }
        }
        File.WriteAllLines(GetAbsolutelyPath(path), testOri);
        //StartProcess();
        arr = File.ReadAllLines(GetAbsolutelyPath(translatePath));
        testOri = new string[arr.Length];
        for (int i = 0, imax = arr.Length; i < imax; i++)
        {
            string line =arr[i];
            string[] tempArr = line.Split(',');
            string ori = tempArr[1];
            testOri[i] = line + "," + translateDic[ori];
        }
        File.WriteAllLines(GetAbsolutelyPath(translatedPath), testOri);
    }

    [ContextMenu("翻译前预处理")]
    void StartProcess()
    {
        ClearTables();
        ReadFile(GetAbsolutelyPath(path));
        // 绝对去重
        RemoveAbsoluteDanfency();
        // 语句拆分
        AnalyzeLines();
        // 进一步去重得到待翻译版本
        GetTranalateData();
    }

    // 文件路径初始化
    [ContextMenu("文件路径初始化")]
    void SetPaths()
    {
        testPath = "Translator/Example/testResult.txt";
        path = "Translator/Example/origin.txt";
        characterPath = "Translator/Example/character.txt";
        translatePath = "Translator/Example/translate.txt";
        translatedPath = "Translator/Example/translated.txt";
        completePath = "Translator/Example/complete.txt";
        errorPath = "Translator/Example/questionList.txt";
    }

    [ContextMenu("翻译")]
    public void Translate()
    {
        Translator t = new Translator(GetAbsolutelyPath(path), oriLan, GetAbsolutelyPath(translatedPath), targetLan);
        t.Translate(GetAbsolutelyPath(completePath), GetAbsolutelyPath(errorPath));
    }

    private string GetAbsolutelyPath(string path)
    {
        return Application.dataPath + "/" + path;
    }
    List<string> completeData = new List<string>();  // （1）完整原句表,绝对去重结果
    // 处理结果
    List<string> chineseData = new List<string>();   // （2）完整原文表
    List<string> characterData = new List<string>(); // （3）完整字符表
    List<string> indexData = new List<string>();     // （4）完整字符索引表
    // 最终给翻译的版本：
    Dictionary<string, string> translateDic = new Dictionary<string, string>(); // <原文key（translateChineseData）:最长待翻译语句（translateData）>

    void ClearTables()
    {
        completeData.Clear();
        translateDic.Clear();
        chineseData.Clear();
        characterData.Clear();
        indexData.Clear();
    }

    // 绝对去重保存到completeData ++
    void RemoveAbsoluteDanfency()
    {
        for (int i = 0; i < rawData.Length; ++i)
        {
            string curLine = rawData[i];
            if (!completeData.Contains(curLine))
            {
                completeData.Add(curLine);

                // 语句拆分
                string characterLine = "";
                string chineseLine = "";
                string indexLine = "";
                Translator.AnalyzeLine(curLine, ref characterLine, ref chineseLine, ref indexLine, oriLan);
                characterData.Add(characterLine);
                chineseData.Add(chineseLine);
                indexData.Add(indexLine);

                // 进一步去重得到待翻译版本
                string key = chineseLine;
                if (translateDic.ContainsKey(key)) // 如果是同样的chinese key，选取非中文字符最多的替换
                {
                    string preLine = translateDic[key];
                    int curCharCount = characterLine.Split(',').Length;
                    int preCharCount = AnalyzeLine(preLine);
                    if (curCharCount > preCharCount)
                    {
                        translateDic[key] = curLine;
                    }
                }
                else
                {
                    translateDic.Add(key, curLine);
                }
            }
        }
    }

    // 语句拆分
    void AnalyzeLines()
    {
        /*
        for (int i = 0; i < completeData.Count; ++i)
        {
            string curLine = completeData[i];
            string characterLine = "";
            string chineseLine = "";
            string indexLine = "";
            Translator.AnalyzeLine(curLine, ref characterLine, ref chineseLine, ref indexLine, oriLan);
            characterData.Add(characterLine);
            chineseData.Add(chineseLine);
            indexData.Add(indexLine);
        }
        */
        try
        {
            StreamWriter sw = new StreamWriter(GetAbsolutelyPath(characterPath), false, Encoding.UTF8);
            for (int i = 0; i < characterData.Count; ++i)
            {
                string newLine = string.Format("{0},{1},{2}", chineseData[i], characterData[i], indexData[i]);
                sw.WriteLine(newLine);
            }
            sw.Close();
        }
        catch (System.IndexOutOfRangeException e)
        {
            Debug.Log(e.Message);
        }
    }

    // 进一步去重得到待翻译版本
    void GetTranalateData()
    {
        /*
        for (int i = 0; i < chineseData.Count; ++i)
        {
            string key = chineseData[i];
            if (translateDic.ContainsKey(key)) // 如果是同样的chinese key，选取非中文字符最多的替换
            {
                string curChineseLine = completeData[i];
                string curCharacterLine = characterData[i];
                string chineseLine = translateDic[key];
                int curCharCount = curCharacterLine.Split(',').Length;
                int preCharCount = AnalyzeLine(chineseLine);
                if (curCharCount > preCharCount)
                {
                    translateDic[key] = curChineseLine;
                }
            }
            else
            {
                translateDic.Add(key, completeData[i]);
            }
        }
        */

        StreamWriter sw = new StreamWriter(GetAbsolutelyPath(translatePath), false, Encoding.UTF8);
        foreach (KeyValuePair<string, string> pair in translateDic)
        {
            string newLine = string.Format("{0},{1}", pair.Key, pair.Value);
            sw.WriteLine(newLine);
        }
        sw.Close();
    }

    // 获取原句字符段个数
    int AnalyzeLine(string curLine, Languages language = Languages.Chinese)
    {
        string s1 = "", s2 = "", s3 = "";
        return Translator.AnalyzeLine(curLine, ref s1, ref s2, ref s3, language);
    }

    // 读取原数据
    void ReadFile(string path)
    {
        rawData = File.ReadAllLines(path, System.Text.Encoding.UTF8);
    }
    void WriteFile(string path, string[] str)
    {
        File.WriteAllLines(path, str);
    }
}
