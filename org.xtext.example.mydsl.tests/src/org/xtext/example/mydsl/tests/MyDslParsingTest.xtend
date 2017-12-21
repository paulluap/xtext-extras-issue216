/*
 * generated by Xtext 2.12.0
 */
package org.xtext.example.mydsl.tests

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtext.generator.IFilePostProcessor
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.util.StringInputStream
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.xbase.compiler.IGeneratorConfigProvider
import org.eclipse.xtext.xbase.compiler.JvmModelGenerator
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith
import org.xtext.example.mydsl.myDsl.Model

@RunWith(XtextRunner)
@InjectWith(MyDslInjectorProvider)
class MyDslParsingTest {
	@Inject
	ParseHelper<Model> parseHelper

	@Test
	def void compilationTest1() {
		models(true, 
		'''
		element MyElement : String
		collection MyCollection of MyElement
		'''
		).map[
			eResource.contents.filter(JvmDeclaredType).compile(true)
		].join("\n")=>[
			Assert.assertEquals('''
			import java.util.function.Supplier;
			
			@SuppressWarnings("all")
			public abstract class MyElement implements Supplier<String> {
			  private String foo;
			}
			
			import java.util.Collection;
			
			@SuppressWarnings("all")
			public abstract class MyCollection implements Collection<String> {
			}
			'''.toString, it)
			
		]
	}
	
	/**
	 * here the code causes: 
	 * org.eclipse.xtext.xbase.resource.BatchLinkableResource.handleCyclicResolution
	 * 
	 * the type argument ends up with Supplier<void>
	 */
	@Test
	def void compilationTest2(){
		models(false, 
		'''
		collection MyCollection of MyElement
		''',
		'''
		element MyElement : String
		'''
		).map[
			eResource.contents.filter(JvmDeclaredType).compile(true)
		].join("\n")=>[
			Assert.assertEquals('''
			import java.util.Collection;
			
			@SuppressWarnings("all")
			public abstract class MyCollection implements Collection<String> {
			}
			
			import java.util.function.Supplier;
			
			@SuppressWarnings("all")
			public abstract class MyElement implements /* Supplier<String> */ {
			  private String foo;
			}
			'''.toString, it)
		]
	}
	
	@Test
	def void compilationTest3(){
		models(true, 
		'''
		element MyElement : String
		''',
		'''
		collection MyCollection of MyElement
		'''
		).map[
			eResource.contents.filter(JvmDeclaredType).compile(true)
		].join("\n")=>[
			Assert.assertEquals(
			'''
			import java.util.function.Supplier;
			
			@SuppressWarnings("all")
			public abstract class MyElement implements Supplier<String> {
			  private String foo;
			}
			
			import java.util.Collection;
			
			@SuppressWarnings("all")
			public abstract class MyCollection implements Collection<String> {
			}
			'''.toString, it)
		]
	}
	
	@Test
	def void compilationTest4(){
		models(true, 
		'''element MyString : String''',
		'''
		element MyElement : MyString
		collection MyCollection of MyElement
		'''
		).map[
			eResource.contents.filter(JvmDeclaredType).compile(true)
		].join("\n")=>[
			Assert.assertEquals('''
			import java.util.function.Supplier;
			
			@SuppressWarnings("all")
			public abstract class MyString implements Supplier<String> {
			  private String foo;
			}
			
			import java.util.function.Supplier;
			
			@SuppressWarnings("all")
			public abstract class MyElement implements Supplier<MyString> {
			  private MyString foo;
			}
			
			import java.util.Collection;
			
			@SuppressWarnings("all")
			public abstract class MyCollection implements Collection<MyString> {
			}
			'''.toString, it)
		]
	}

	
	@Inject protected JvmModelGenerator generator
	@Inject protected IFilePostProcessor postProcessor
	@Inject protected IGeneratorConfigProvider generatorConfigProvider
	@Inject
	private Provider<XtextResourceSet> resourceSetProvider;

	def String compile(Iterable<JvmDeclaredType> jvmTypes, boolean serializeAllTypes) {
		val results = newArrayList
		for (inferredType : jvmTypes) {
//        for (inferredType : model.eResource.contents.filter(typeof(JvmDeclaredType))) {
//            assertFalse(DisableCodeGenerationAdapter::isDisabled(inferredType))
			var javaCode = generator.generateType(inferredType, generatorConfigProvider.get(null));
			javaCode = postProcessor.postProcess(null, javaCode);
			results += javaCode
//            if (useJavaCompiler) {
//                compilationTestHelper.compile(input) [
//                    it.compiledClass
//                ]
//            }
		}
		if (serializeAllTypes)
			return results.join('\n')
		else
			return results.head.toString
	}

	def Iterable<Model> models(boolean validate, String... contents) {
		val set = getResourceSet();
		val result = <Model>newArrayList();

		contents.forEach [ content, i |
			val fileName = "foo" + (i + 1).toString + ".mydsl"
			val resource = set.createResource(URI.createURI(fileName))
			resource.load(new StringInputStream(content), null)

			Assert.assertEquals(resource.getErrors().toString(), 0, resource.getErrors().size());
		]
		for (Resource resource : <Resource>newArrayList(set.getResources())) {
            resource.contents
            EcoreUtil2.resolveLazyCrossReferences(resource, CancelIndicator.NullImpl)
			val model = resource.allContents.findFirst[it instanceof Model] as Model
			if (model != null)
				result.add(model);
		}
		if (validate) {
			result.forEach [
				val issues = (it.eResource as XtextResource).resourceServiceProvider.resourceValidator.validate(
					it.eResource,
					CheckMode.ALL,
					CancelIndicator.NullImpl
				)
				Assert.assertTrue("Resource contained errors : " + issues.toString(), issues.isEmpty());
			]
		}

		return result
	}

	def XtextResourceSet getResourceSet() {
		val set = resourceSetProvider.get();
		set.setClasspathURIContext(getClass().getClassLoader());
		return set;
	}
	
}